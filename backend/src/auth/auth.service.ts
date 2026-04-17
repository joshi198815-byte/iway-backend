import { BadRequestException, Injectable, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { createHash, randomInt } from 'node:crypto';
import { JwtService } from '@nestjs/jwt';
import { UserRole, VerificationChannel } from '@prisma/client';
import { GeoService } from '../geo/geo.service';
import { StorageService } from '../storage/storage.service';
import { TravelersService } from '../travelers/travelers.service';
import { UsersService } from '../users/users.service';
import { hashPassword, verifyPassword } from '../common/utils/password.util';
import { LoginDto } from './dto/login.dto';
import { RegisterCustomerDto } from './dto/register-customer.dto';
import { RegisterTravelerAuthDto } from './dto/register-traveler-auth.dto';
import { AntiFraudService } from '../anti-fraud/anti-fraud.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { JobsService } from '../jobs/jobs.service';

@Injectable()
export class AuthService implements OnModuleInit {
  private get autoVerifyPhoneForTesting() {
    return process.env.AUTO_VERIFY_PHONE_FOR_TESTING === 'true';
  }

  constructor(
    private readonly usersService: UsersService,
    private readonly travelersService: TravelersService,
    private readonly geoService: GeoService,
    private readonly jwtService: JwtService,
    private readonly storageService: StorageService,
    private readonly antiFraudService: AntiFraudService,
    private readonly notificationsService: NotificationsService,
    private readonly prisma: PrismaService,
    private readonly jobsService: JobsService,
  ) {}

  private async markPhoneVerified(userId: string) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { phoneVerified: true },
      select: {
        id: true,
        role: true,
        status: true,
        fullName: true,
        email: true,
        phone: true,
        countryCode: true,
        detectedCountryCode: true,
        createdAt: true,
        updatedAt: true,
        phoneVerified: true,
        emailVerified: true,
      },
    });
  }

  onModuleInit() {
    this.jobsService.registerHandler('anti-fraud-scan', async (payload) => {
      const userId = typeof payload.userId === 'string' ? payload.userId : null;
      if (!userId) {
        throw new Error('missing_user_id');
      }

      await this.antiFraudService.buildUserRiskSignals(userId);
    });
  }

  async registerCustomer(payload: RegisterCustomerDto) {
    const passwordHash = await hashPassword(payload.password);
    const detectedCountryCode = this.geoService.normalizeCountryCode(payload.countryCode);

    let user = await this.usersService.createUser({
      role: UserRole.customer,
      fullName: payload.fullName,
      email: payload.email.trim().toLowerCase(),
      phone: payload.phone.trim(),
      passwordHash,
      countryCode: detectedCountryCode ?? payload.countryCode,
      detectedCountryCode: detectedCountryCode ?? undefined,
      stateRegion: payload.stateRegion,
      city: payload.city,
      address: payload.address,
    });

    await this.jobsService.enqueue({
      name: 'anti-fraud-scan',
      payload: { userId: user.id, source: 'register_customer' },
      maxAttempts: 3,
      initialDelayMs: 250,
    });

    if (this.autoVerifyPhoneForTesting) {
      user = await this.markPhoneVerified(user.id);
    }

    return {
      user,
      accessToken: this.jwtService.sign({ sub: user.id, role: user.role }),
    };
  }

  async registerTraveler(payload: RegisterTravelerAuthDto) {
    const passwordHash = await hashPassword(payload.password);
    const detectedCountryCode = this.geoService.normalizeCountryCode(
      payload.detectedCountryCode ?? payload.countryCode,
    );

    let user = await this.usersService.createUser({
      role: UserRole.traveler,
      fullName: payload.fullName,
      email: payload.email.trim().toLowerCase(),
      phone: payload.phone.trim(),
      passwordHash,
      countryCode: detectedCountryCode ?? undefined,
      detectedCountryCode: detectedCountryCode ?? undefined,
      stateRegion: payload.stateRegion,
      city: payload.city,
      address: payload.address,
    });

    const documentUrl = payload.documentUrl
      ? payload.documentUrl
      : payload.documentBase64
          ? (
              await this.storageService.uploadBase64(
                {
                  bucket: 'documents',
                  base64: payload.documentBase64,
                  fileName: `traveler-document-${payload.documentNumber}-${Date.now()}`,
                },
                user.id,
              )
            ).url
          : undefined;

    const selfieUrl = payload.selfieUrl
      ? payload.selfieUrl
      : payload.selfieBase64
          ? (
              await this.storageService.uploadBase64(
                {
                  bucket: 'documents',
                  base64: payload.selfieBase64,
                  fileName: `traveler-selfie-${payload.documentNumber}-${Date.now()}`,
                },
                user.id,
              )
            ).url
          : undefined;

    const travelerProfile = await this.travelersService.createTravelerProfile({
      userId: user.id,
      travelerType: payload.travelerType,
      documentNumber: payload.documentNumber,
      documentUrl,
      selfieUrl,
      detectedCountryCode: detectedCountryCode ?? undefined,
    });

    const travelerFiles = [documentUrl, selfieUrl].filter(
      (value): value is string => value != null,
    );
    if (travelerFiles.length > 0) {
      await this.storageService.attachFilesToEntity({
        ownerId: user.id,
        urls: travelerFiles,
        linkedEntityType: 'traveler_profile',
        linkedEntityId: travelerProfile.id,
        purpose: 'identity_verification',
      });
    }

    await this.jobsService.enqueue({
      name: 'anti-fraud-scan',
      payload: { userId: user.id, source: 'register_traveler' },
      maxAttempts: 3,
      initialDelayMs: 250,
    });

    if (this.autoVerifyPhoneForTesting) {
      user = await this.markPhoneVerified(user.id);
    }

    return {
      user,
      travelerProfile,
      accessToken: this.jwtService.sign({ sub: user.id, role: user.role }),
    };
  }

  private hashVerificationCode(code: string) {
    return createHash('sha256').update(code).digest('hex');
  }

  async requestVerificationCode(userId: string, channel: VerificationChannel) {
    const user = await this.usersService.findByIdForSession(userId);

    if (!user) {
      throw new UnauthorizedException('Sesión inválida.');
    }

    if (channel === 'phone' && this.autoVerifyPhoneForTesting) {
      await this.markPhoneVerified(userId);
      return { channel, autoVerified: true, testingMode: true };
    }

    const alreadyVerified = channel === 'phone' ? user.phoneVerified : user.emailVerified;
    if (alreadyVerified) {
      return { channel, alreadyVerified: true };
    }

    await this.prisma.verificationCode.updateMany({
      where: { userId, channel, consumedAt: null },
      data: { consumedAt: new Date() },
    });

    const code = randomInt(100000, 1000000).toString();
    await this.prisma.verificationCode.create({
      data: {
        userId,
        channel,
        codeHash: this.hashVerificationCode(code),
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      },
    });

    await this.notificationsService.sendPush(
      userId,
      channel === 'phone' ? 'Código de verificación de teléfono' : 'Código de verificación de correo',
      `Tu código iWay es ${code}. Vence en 10 minutos.`,
      'contact_verification',
    );

    return { channel, sent: true, expiresInMinutes: 10 };
  }

  async updatePendingPhone(userId: string, phone: string) {
    const user = await this.usersService.findByIdForSession(userId);

    if (!user) {
      throw new UnauthorizedException('Sesión inválida.');
    }

    if (user.phoneVerified) {
      throw new BadRequestException('Tu teléfono ya fue verificado y no se puede cambiar desde esta pantalla.');
    }

    const normalizedPhone = phone.trim();
    const existing = await this.prisma.user.findFirst({
      where: {
        phone: normalizedPhone,
        id: { not: userId },
      },
      select: { id: true },
    });

    if (existing) {
      throw new BadRequestException('Ese teléfono ya está en uso por otra cuenta.');
    }

    await this.prisma.$transaction([
      this.prisma.verificationCode.updateMany({
        where: { userId, channel: 'phone', consumedAt: null },
        data: { consumedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: { phone: normalizedPhone, phoneVerified: false },
      }),
    ]);

    return this.me(userId);
  }

  async verifyContactCode(userId: string, channel: VerificationChannel, code: string) {
    const verification = await this.prisma.verificationCode.findFirst({
      where: { userId, channel, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    if (!verification || verification.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException('El código ya venció o no existe.');
    }

    if (verification.codeHash !== this.hashVerificationCode(code.trim())) {
      await this.prisma.verificationCode.update({
        where: { id: verification.id },
        data: { attempts: verification.attempts + 1 },
      });
      throw new BadRequestException('Código inválido.');
    }

    await this.prisma.$transaction([
      this.prisma.verificationCode.update({
        where: { id: verification.id },
        data: { consumedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: channel === 'phone' ? { phoneVerified: true } : { emailVerified: true },
      }),
    ]);

    return this.me(userId);
  }

  async me(userId: string) {
    const user = await this.usersService.findByIdForSession(userId);

    if (!user) {
      throw new UnauthorizedException('Sesión inválida.');
    }

    return {
      user: {
        id: user.id,
        role: user.role,
        status: user.status,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        detectedCountryCode: user.detectedCountryCode,
        phoneVerified: user.phoneVerified,
        emailVerified: user.emailVerified,
        travelerProfile: user.travelerProfile,
      },
    };
  }

  async login(payload: LoginDto) {
    let user = await this.usersService.findByEmail(payload.email.trim().toLowerCase());

    if (!user) {
      throw new UnauthorizedException('Credenciales inválidas.');
    }

    const passwordValid = await verifyPassword(payload.password, user.passwordHash);

    if (!passwordValid) {
      throw new UnauthorizedException('Credenciales inválidas.');
    }

    if (
      user.role === UserRole.traveler &&
      user.travelerProfile?.status === 'blocked_for_debt'
    ) {
      throw new BadRequestException('Tu cuenta está bloqueada por comisiones pendientes.');
    }

    if (this.autoVerifyPhoneForTesting && !user.phoneVerified && [UserRole.customer, UserRole.traveler].includes(user.role)) {
      await this.markPhoneVerified(user.id);
      const refreshedUser = await this.usersService.findByEmail(payload.email.trim().toLowerCase());
      if (!refreshedUser) {
        throw new UnauthorizedException('Credenciales inválidas.');
      }
      user = refreshedUser;
    }

    return {
      accessToken: this.jwtService.sign({ sub: user.id, role: user.role }),
      user: {
        id: user.id,
        role: user.role,
        status: user.status,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        detectedCountryCode: user.detectedCountryCode,
        phoneVerified: user.phoneVerified,
        emailVerified: user.emailVerified,
        travelerProfile: user.travelerProfile,
      },
    };
  }
}
