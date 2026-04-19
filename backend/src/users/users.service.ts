import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRole, UserStatus } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../database/prisma/prisma.service';
import { hashPassword } from '../common/utils/password.util';
import { CreateUserDto } from './dto/create-user.dto';
import { CreateCollaboratorDto } from './dto/create-collaborator.dto';
import { UpdateCollaboratorRoleDto } from './dto/update-collaborator-role.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  private readonly collaboratorRoles: UserRole[] = [UserRole.admin, UserRole.support];

  private assertAdmin(requester: { role: string; sub: string }) {
    if (requester.role !== UserRole.admin) {
      throw new ForbiddenException('Solo un admin puede administrar colaboradores.');
    }
  }

  private assertCollaboratorRole(role: UserRole) {
    if (!this.collaboratorRoles.includes(role)) {
      throw new BadRequestException('Los colaboradores solo pueden tener rol admin o support.');
    }
  }

  private generateTemporaryPassword(length = 14) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
    const bytes = randomBytes(length);
    return Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join('');
  }

  async ensureUniqueUser(email: string, phone: string) {
    const existing = await this.prisma.user.findFirst({
      where: {
        OR: [{ email }, { phone }],
      },
    });

    if (existing) {
      throw new BadRequestException('Ya existe un usuario con ese correo o teléfono.');
    }
  }

  async createUser(payload: CreateUserDto) {
    await this.ensureUniqueUser(payload.email, payload.phone);

    return this.prisma.user.create({
      data: {
        role: payload.role,
        fullName: payload.fullName,
        email: payload.email,
        phone: payload.phone,
        passwordHash: payload.passwordHash,
        countryCode: payload.countryCode,
        detectedCountryCode: payload.detectedCountryCode,
        stateRegion: payload.stateRegion,
        city: payload.city,
        address: payload.address,
      },
      select: {
        id: true,
        role: true,
        status: true,
        fullName: true,
        email: true,
        phone: true,
        countryCode: true,
        stateRegion: true,
        city: true,
        address: true,
        detectedCountryCode: true,
        phoneVerified: true,
        emailVerified: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async createCollaborator(payload: CreateCollaboratorDto, requester: { role: string; sub: string }) {
    this.assertAdmin(requester);
    this.assertCollaboratorRole(payload.role);

    const password = payload.password?.trim() || this.generateTemporaryPassword();
    const passwordHash = await hashPassword(password);

    const collaborator = await this.createUser({
      role: payload.role,
      fullName: payload.fullName.trim(),
      email: payload.email.trim().toLowerCase(),
      phone: payload.phone.trim(),
      passwordHash,
      countryCode: payload.countryCode?.trim(),
      detectedCountryCode: payload.detectedCountryCode?.trim(),
      stateRegion: payload.stateRegion?.trim(),
      city: payload.city?.trim(),
      address: payload.address?.trim(),
    });

    return {
      collaborator,
      temporaryPassword: password,
      mustChangePassword: true,
    };
  }

  async listCollaborators(requester: { role: string; sub: string }) {
    this.assertAdmin(requester);

    const collaborators = await this.prisma.user.findMany({
      where: {
        role: {
          in: this.collaboratorRoles,
        },
      },
      orderBy: [{ createdAt: 'desc' }],
      select: {
        id: true,
        role: true,
        status: true,
        fullName: true,
        email: true,
        phone: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return { collaborators };
  }

  async updateCollaborator(userId: string, payload: UpdateCollaboratorRoleDto, requester: { role: string; sub: string }) {
    this.assertAdmin(requester);

    const existing = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true },
    });

    if (!existing) {
      throw new NotFoundException('Colaborador no encontrado.');
    }

    this.assertCollaboratorRole(existing.role);
    if (payload.role) {
      this.assertCollaboratorRole(payload.role);
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        role: payload.role,
        status: payload.status,
        fullName: payload.fullName?.trim(),
      },
      select: {
        id: true,
        role: true,
        status: true,
        fullName: true,
        email: true,
        phone: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async resetCollaboratorPassword(userId: string, password: string | undefined, requester: { role: string; sub: string }) {
    this.assertAdmin(requester);

    const existing = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, email: true, fullName: true },
    });

    if (!existing) {
      throw new NotFoundException('Colaborador no encontrado.');
    }

    this.assertCollaboratorRole(existing.role);

    const temporaryPassword = password?.trim() || this.generateTemporaryPassword();
    const passwordHash = await hashPassword(temporaryPassword);

    const collaborator = await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
      select: {
        id: true,
        role: true,
        status: true,
        fullName: true,
        email: true,
        phone: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return {
      collaborator,
      temporaryPassword,
      mustChangePassword: true,
    };
  }

  async findByEmail(email: string) {
    return this.prisma.user.findUnique({
      where: { email },
      include: {
        travelerProfile: {
          include: {
            routes: true,
          },
        },
        uploadedFiles: {
          where: { purpose: 'profile_selfie' },
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
    });
  }

  async findByIdForSession(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        role: true,
        status: true,
        fullName: true,
        email: true,
        phone: true,
        countryCode: true,
        stateRegion: true,
        city: true,
        address: true,
        detectedCountryCode: true,
        phoneVerified: true,
        emailVerified: true,
        travelerProfile: {
          include: {
            routes: true,
          },
        },
        uploadedFiles: {
          where: { purpose: 'profile_selfie' },
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
    });
  }

  async findPublicById(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        role: true,
        status: true,
        fullName: true,
        countryCode: true,
        stateRegion: true,
        address: true,
        detectedCountryCode: true,
        travelerProfile: {
          select: {
            travelerType: true,
            status: true,
            ratingAvg: true,
            ratingCount: true,
            kycTier: true,
          },
        },
      },
    });
  }


  async updateSelfProfile(
    userId: string,
    payload: {
      fullName?: string;
      phone?: string;
      countryCode?: string;
      stateRegion?: string;
      address?: string;
      selfieUrl?: string;
      phoneVerified?: boolean;
    },
  ) {
    const existing = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { travelerProfile: true },
    });

    if (!existing) return null;

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        fullName: payload.fullName?.trim() || existing.fullName,
        phone: payload.phone?.trim() || existing.phone,
        countryCode: payload.countryCode?.trim() || existing.countryCode,
        stateRegion: payload.stateRegion?.trim() || null,
        address: payload.address?.trim() || null,
        ...(payload.phoneVerified == null ? {} : { phoneVerified: payload.phoneVerified }),
      },
    });

    if (payload.selfieUrl != null) {
      const trimmedSelfieUrl = payload.selfieUrl.trim();

      await this.prisma.uploadedFile.updateMany({
        where: {
          ownerId: userId,
          purpose: 'profile_selfie',
          ...(trimmedSelfieUrl == '' ? {} : { url: { not: trimmedSelfieUrl } }),
        },
        data: {
          purpose: 'profile_selfie_archive',
        },
      });

      if (trimmedSelfieUrl != '') {
        await this.prisma.uploadedFile.updateMany({
          where: {
            ownerId: userId,
            url: trimmedSelfieUrl,
          },
          data: {
            linkedEntityType: 'user_profile',
            linkedEntityId: userId,
            purpose: 'profile_selfie',
          },
        });
      }

      if (existing.role === 'traveler' && existing.travelerProfile) {
        await this.prisma.travelerProfile.update({
          where: { userId },
          data: {
            selfieUrl: trimmedSelfieUrl == '' ? null : trimmedSelfieUrl,
          },
        });
      }
    }

    return this.findByIdForSession(userId);
  }

  getBlueprint() {
    return {
      roles: ['customer', 'traveler', 'admin', 'support'],
      collaboratorRoles: ['admin', 'support'],
      antiFraud: ['phone verification', 'country detection', 'audit logs'],
      protectedContactData: true,
    };
  }
}
