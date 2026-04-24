import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { constants as fsConstants } from 'node:fs';
import { PrismaService } from '../database/prisma/prisma.service';
import { UploadBase64Dto } from './dto/upload-base64.dto';

@Injectable()
export class StorageService {
  constructor(private readonly prisma: PrismaService) {}

  private readonly buckets = ['documents', 'shipment-images', 'transfer-proofs'] as const;

  getUploadBlueprint() {
    return {
      buckets: this.buckets,
      mode: process.env.STORAGE_MODE ?? 'local-disk',
      baseUrl: process.env.STORAGE_PROTECTED_BASE_URL ?? '/api/storage/file',
      uploadsDir: process.env.UPLOADS_DIR ?? './uploads',
      retentionPolicy: {
        documents: 'active_account_plus_compliance_window',
        shipmentImages: 'support_and_dispute_window',
        transferProofs: 'financial_audit_window',
      },
    };
  }

  async uploadBase64(payload: UploadBase64Dto, ownerId: string) {
    if (!this.buckets.includes(payload.bucket as (typeof this.buckets)[number])) {
      throw new BadRequestException('Bucket no soportado.');
    }

    const match = payload.base64.match(/^data:(.+?);base64,(.+)$/);
    const contentType = match?.[1] ?? 'image/jpeg';
    const base64Content = match?.[2] ?? payload.base64;

    let extension = '.jpg';
    if (contentType.includes('png')) extension = '.png';
    if (contentType.includes('webp')) extension = '.webp';
    if (contentType.includes('pdf')) extension = '.pdf';

    let buffer: Buffer;
    try {
      buffer = Buffer.from(base64Content, 'base64');
    } catch (_) {
      throw new BadRequestException('Archivo base64 inválido.');
    }

    const safeName = (payload.fileName ?? `upload-${Date.now()}`)
      .replace(/[^a-zA-Z0-9-_]/g, '-')
      .replace(/-+/g, '-')
      .toLowerCase();
    const fileName = `${payload.bucket}-${ownerId}-${safeName}${extension}`;
    const uploadsRoot = path.resolve(process.cwd(), process.env.UPLOADS_DIR ?? 'uploads');
    const legacyOwnerDir = path.join(uploadsRoot, payload.bucket, ownerId);
    await mkdir(uploadsRoot, { recursive: true });
    await mkdir(legacyOwnerDir, { recursive: true });

    const absolutePath = path.join(uploadsRoot, fileName);
    const legacyAbsolutePath = path.join(legacyOwnerDir, fileName);
    await writeFile(absolutePath, buffer);
    await writeFile(legacyAbsolutePath, buffer);

    const relativePath = `/uploads/${fileName}`;
    const protectedUrl = `/api/storage/file/${payload.bucket}/${ownerId}/${fileName}`;

    const uploadedFile = await this.prisma.uploadedFile.create({
      data: {
        ownerId,
        bucket: payload.bucket,
        fileName,
        contentType,
        sizeBytes: buffer.byteLength,
        path: relativePath,
        url: relativePath,
        isProtected: true,
      },
    });

    return {
      id: uploadedFile.id,
      bucket: payload.bucket,
      ownerId,
      fileName,
      contentType,
      sizeBytes: buffer.byteLength,
      path: relativePath,
      url: relativePath,
      protectedUrl,
      publicUrl: relativePath,
    };
  }

  async attachFilesToEntity(params: {
    ownerId: string;
    urls: string[];
    linkedEntityType: string;
    linkedEntityId: string;
    purpose: string;
  }) {
    const urls = params.urls.filter((value) => value.trim().length > 0);
    if (urls.length === 0) {
      return { count: 0 };
    }

    return this.prisma.uploadedFile.updateMany({
      where: {
        ownerId: params.ownerId,
        url: { in: urls },
      },
      data: {
        linkedEntityType: params.linkedEntityType,
        linkedEntityId: params.linkedEntityId,
        purpose: params.purpose,
      },
    });
  }

  async resolveProtectedFile(params: {
    bucket: string;
    ownerId: string;
    fileName: string;
    requesterId: string;
    requesterRole?: string;
  }) {
    const isPrivileged = ['admin', 'support'].includes(params.requesterRole ?? '');
    if (!isPrivileged && params.ownerId !== params.requesterId) {
      throw new ForbiddenException('No tienes acceso a este archivo.');
    }

    if (!this.buckets.includes(params.bucket as (typeof this.buckets)[number])) {
      throw new BadRequestException('Bucket no soportado.');
    }

    const absolutePath = path.join(
      path.resolve(process.cwd(), process.env.UPLOADS_DIR ?? 'uploads'),
      params.bucket,
      params.ownerId,
      params.fileName,
    );

    try {
      await access(absolutePath, fsConstants.R_OK);
    } catch (_) {
      throw new BadRequestException('Archivo no encontrado.');
    }

    return absolutePath;
  }

  async getProtectedFilePreview(params: {
    bucket: string;
    ownerId: string;
    fileName: string;
    requesterId: string;
    requesterRole?: string;
  }) {
    const absolutePath = await this.resolveProtectedFile(params);
    const buffer = await readFile(absolutePath);

    const uploadedFile = await this.prisma.uploadedFile.findFirst({
      where: {
        bucket: params.bucket,
        ownerId: params.ownerId,
        fileName: params.fileName,
      },
      orderBy: { createdAt: 'desc' },
    });

    const contentType = uploadedFile?.contentType ?? this.inferContentType(params.fileName);

    return {
      bucket: params.bucket,
      ownerId: params.ownerId,
      fileName: params.fileName,
      contentType,
      sizeBytes: buffer.byteLength,
      dataUrl: `data:${contentType};base64,${buffer.toString('base64')}`,
    };
  }

  private inferContentType(fileName: string) {
    const lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
