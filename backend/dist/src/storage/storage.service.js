"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StorageService = void 0;
const common_1 = require("@nestjs/common");
const promises_1 = require("node:fs/promises");
const node_path_1 = __importDefault(require("node:path"));
const node_fs_1 = require("node:fs");
const prisma_service_1 = require("../database/prisma/prisma.service");
let StorageService = class StorageService {
    constructor(prisma) {
        this.prisma = prisma;
        this.buckets = ['documents', 'shipment-images', 'transfer-proofs'];
    }
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
    async uploadBase64(payload, ownerId) {
        if (!this.buckets.includes(payload.bucket)) {
            throw new common_1.BadRequestException('Bucket no soportado.');
        }
        const match = payload.base64.match(/^data:(.+?);base64,(.+)$/);
        const contentType = match?.[1] ?? 'image/jpeg';
        const base64Content = match?.[2] ?? payload.base64;
        let extension = '.jpg';
        if (contentType.includes('png'))
            extension = '.png';
        if (contentType.includes('webp'))
            extension = '.webp';
        if (contentType.includes('pdf'))
            extension = '.pdf';
        let buffer;
        try {
            buffer = Buffer.from(base64Content, 'base64');
        }
        catch (_) {
            throw new common_1.BadRequestException('Archivo base64 inválido.');
        }
        const safeName = (payload.fileName ?? `upload-${Date.now()}`)
            .replace(/[^a-zA-Z0-9-_]/g, '-')
            .replace(/-+/g, '-')
            .toLowerCase();
        const fileName = `${safeName}${extension}`;
        const uploadsRoot = node_path_1.default.resolve(process.cwd(), process.env.UPLOADS_DIR ?? 'uploads');
        const ownerDir = node_path_1.default.join(uploadsRoot, payload.bucket, ownerId);
        await (0, promises_1.mkdir)(ownerDir, { recursive: true });
        const absolutePath = node_path_1.default.join(ownerDir, fileName);
        await (0, promises_1.writeFile)(absolutePath, buffer);
        const relativePath = `/uploads/${payload.bucket}/${ownerId}/${fileName}`;
        const protectedUrl = `/api/storage/file/${payload.bucket}/${ownerId}/${fileName}`;
        const uploadedFile = await this.prisma.uploadedFile.create({
            data: {
                ownerId,
                bucket: payload.bucket,
                fileName,
                contentType,
                sizeBytes: buffer.byteLength,
                path: relativePath,
                url: protectedUrl,
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
            url: protectedUrl,
            protectedUrl,
            publicUrl: relativePath,
        };
    }
    async attachFilesToEntity(params) {
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
    async resolveProtectedFile(params) {
        const isPrivileged = ['admin', 'support'].includes(params.requesterRole ?? '');
        if (!isPrivileged && params.ownerId !== params.requesterId) {
            throw new common_1.ForbiddenException('No tienes acceso a este archivo.');
        }
        if (!this.buckets.includes(params.bucket)) {
            throw new common_1.BadRequestException('Bucket no soportado.');
        }
        const absolutePath = node_path_1.default.join(node_path_1.default.resolve(process.cwd(), process.env.UPLOADS_DIR ?? 'uploads'), params.bucket, params.ownerId, params.fileName);
        try {
            await (0, promises_1.access)(absolutePath, node_fs_1.constants.R_OK);
        }
        catch (_) {
            throw new common_1.BadRequestException('Archivo no encontrado.');
        }
        return absolutePath;
    }
};
exports.StorageService = StorageService;
exports.StorageService = StorageService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], StorageService);
//# sourceMappingURL=storage.service.js.map