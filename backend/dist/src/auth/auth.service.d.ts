import { OnModuleInit } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { VerificationChannel } from '@prisma/client';
import { GeoService } from '../geo/geo.service';
import { StorageService } from '../storage/storage.service';
import { TravelersService } from '../travelers/travelers.service';
import { UsersService } from '../users/users.service';
import { LoginDto } from './dto/login.dto';
import { RegisterCustomerDto } from './dto/register-customer.dto';
import { RegisterTravelerAuthDto } from './dto/register-traveler-auth.dto';
import { AntiFraudService } from '../anti-fraud/anti-fraud.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { JobsService } from '../jobs/jobs.service';
export declare class AuthService implements OnModuleInit {
    private readonly usersService;
    private readonly travelersService;
    private readonly geoService;
    private readonly jwtService;
    private readonly storageService;
    private readonly antiFraudService;
    private readonly notificationsService;
    private readonly prisma;
    private readonly jobsService;
    constructor(usersService: UsersService, travelersService: TravelersService, geoService: GeoService, jwtService: JwtService, storageService: StorageService, antiFraudService: AntiFraudService, notificationsService: NotificationsService, prisma: PrismaService, jobsService: JobsService);
    onModuleInit(): void;
    registerCustomer(payload: RegisterCustomerDto): Promise<{
        user: {
            role: import(".prisma/client").$Enums.UserRole;
            id: string;
            createdAt: Date;
            fullName: string;
            email: string;
            phone: string;
            countryCode: string | null;
            detectedCountryCode: string | null;
        };
        accessToken: string;
    }>;
    registerTraveler(payload: RegisterTravelerAuthDto): Promise<{
        user: {
            role: import(".prisma/client").$Enums.UserRole;
            id: string;
            createdAt: Date;
            fullName: string;
            email: string;
            phone: string;
            countryCode: string | null;
            detectedCountryCode: string | null;
        };
        travelerProfile: {
            routes: {
                active: boolean;
                id: string;
                createdAt: Date;
                direction: import(".prisma/client").$Enums.ShipmentDirection;
                travelerProfileId: string;
            }[];
        } & {
            status: import(".prisma/client").$Enums.TravelerStatus;
            id: string;
            createdAt: Date;
            updatedAt: Date;
            userId: string;
            trustScore: number;
            travelerType: import(".prisma/client").$Enums.TravelerType;
            verificationScore: number;
            ratingAvg: import("@prisma/client/runtime/library").Decimal;
            ratingCount: number;
            dpiOrPassport: string | null;
            documentUrl: string | null;
            selfieUrl: string | null;
            currentDebt: import("@prisma/client/runtime/library").Decimal;
            preferredCutoffDay: number;
            weeklyBlockEnabled: boolean;
            payoutHoldEnabled: boolean;
            kycTier: import(".prisma/client").$Enums.KycTier;
            lastKycReviewAt: Date | null;
            blockedReason: string | null;
        };
        accessToken: string;
    }>;
    private hashVerificationCode;
    requestVerificationCode(userId: string, channel: VerificationChannel): Promise<{
        channel: import(".prisma/client").$Enums.VerificationChannel;
        alreadyVerified: boolean;
        sent?: undefined;
        expiresInMinutes?: undefined;
    } | {
        channel: import(".prisma/client").$Enums.VerificationChannel;
        sent: boolean;
        expiresInMinutes: number;
        alreadyVerified?: undefined;
    }>;
    verifyContactCode(userId: string, channel: VerificationChannel, code: string): Promise<{
        user: {
            id: string;
            role: import(".prisma/client").$Enums.UserRole;
            status: import(".prisma/client").$Enums.UserStatus;
            fullName: string;
            email: string;
            phone: string;
            detectedCountryCode: string | null;
            phoneVerified: boolean;
            emailVerified: boolean;
            travelerProfile: {
                status: import(".prisma/client").$Enums.TravelerStatus;
                id: string;
                createdAt: Date;
                updatedAt: Date;
                userId: string;
                trustScore: number;
                travelerType: import(".prisma/client").$Enums.TravelerType;
                verificationScore: number;
                ratingAvg: import("@prisma/client/runtime/library").Decimal;
                ratingCount: number;
                dpiOrPassport: string | null;
                documentUrl: string | null;
                selfieUrl: string | null;
                currentDebt: import("@prisma/client/runtime/library").Decimal;
                preferredCutoffDay: number;
                weeklyBlockEnabled: boolean;
                payoutHoldEnabled: boolean;
                kycTier: import(".prisma/client").$Enums.KycTier;
                lastKycReviewAt: Date | null;
                blockedReason: string | null;
            } | null;
        };
    }>;
    me(userId: string): Promise<{
        user: {
            id: string;
            role: import(".prisma/client").$Enums.UserRole;
            status: import(".prisma/client").$Enums.UserStatus;
            fullName: string;
            email: string;
            phone: string;
            detectedCountryCode: string | null;
            phoneVerified: boolean;
            emailVerified: boolean;
            travelerProfile: {
                status: import(".prisma/client").$Enums.TravelerStatus;
                id: string;
                createdAt: Date;
                updatedAt: Date;
                userId: string;
                trustScore: number;
                travelerType: import(".prisma/client").$Enums.TravelerType;
                verificationScore: number;
                ratingAvg: import("@prisma/client/runtime/library").Decimal;
                ratingCount: number;
                dpiOrPassport: string | null;
                documentUrl: string | null;
                selfieUrl: string | null;
                currentDebt: import("@prisma/client/runtime/library").Decimal;
                preferredCutoffDay: number;
                weeklyBlockEnabled: boolean;
                payoutHoldEnabled: boolean;
                kycTier: import(".prisma/client").$Enums.KycTier;
                lastKycReviewAt: Date | null;
                blockedReason: string | null;
            } | null;
        };
    }>;
    login(payload: LoginDto): Promise<{
        accessToken: string;
        user: {
            id: string;
            role: import(".prisma/client").$Enums.UserRole;
            status: import(".prisma/client").$Enums.UserStatus;
            fullName: string;
            email: string;
            phone: string;
            detectedCountryCode: string | null;
            phoneVerified: boolean;
            emailVerified: boolean;
            travelerProfile: ({
                routes: {
                    active: boolean;
                    id: string;
                    createdAt: Date;
                    direction: import(".prisma/client").$Enums.ShipmentDirection;
                    travelerProfileId: string;
                }[];
            } & {
                status: import(".prisma/client").$Enums.TravelerStatus;
                id: string;
                createdAt: Date;
                updatedAt: Date;
                userId: string;
                trustScore: number;
                travelerType: import(".prisma/client").$Enums.TravelerType;
                verificationScore: number;
                ratingAvg: import("@prisma/client/runtime/library").Decimal;
                ratingCount: number;
                dpiOrPassport: string | null;
                documentUrl: string | null;
                selfieUrl: string | null;
                currentDebt: import("@prisma/client/runtime/library").Decimal;
                preferredCutoffDay: number;
                weeklyBlockEnabled: boolean;
                payoutHoldEnabled: boolean;
                kycTier: import(".prisma/client").$Enums.KycTier;
                lastKycReviewAt: Date | null;
                blockedReason: string | null;
            }) | null;
        };
    }>;
}
