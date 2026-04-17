import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { CreateUserDto } from './dto/create-user.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

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
        fullName: true,
        email: true,
        phone: true,
        countryCode: true,
        detectedCountryCode: true,
        createdAt: true,
      },
    });
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
        detectedCountryCode: true,
        phoneVerified: true,
        emailVerified: true,
        travelerProfile: true,
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

  getBlueprint() {
    return {
      roles: ['customer', 'traveler', 'admin', 'support'],
      antiFraud: ['phone verification', 'country detection', 'audit logs'],
      protectedContactData: true,
    };
  }
}
