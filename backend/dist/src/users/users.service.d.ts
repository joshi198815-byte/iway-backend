import { PrismaService } from '../database/prisma/prisma.service';
import { CreateUserDto } from './dto/create-user.dto';
export declare class UsersService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    ensureUniqueUser(email: string, phone: string): Promise<void>;
    createUser(payload: CreateUserDto): Promise<{
        role: import(".prisma/client").$Enums.UserRole;
        id: string;
        createdAt: Date;
        fullName: string;
        email: string;
        phone: string;
        countryCode: string | null;
        detectedCountryCode: string | null;
    }>;
    findByEmail(email: string): Promise<({
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
    } & {
        role: import(".prisma/client").$Enums.UserRole;
        status: import(".prisma/client").$Enums.UserStatus;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        fullName: string;
        email: string;
        phone: string;
        passwordHash: string;
        countryCode: string | null;
        stateRegion: string | null;
        city: string | null;
        address: string | null;
        detectedCountryCode: string | null;
        phoneVerified: boolean;
        emailVerified: boolean;
    }) | null>;
    findPublicById(id: string): Promise<{
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
        role: import(".prisma/client").$Enums.UserRole;
        status: import(".prisma/client").$Enums.UserStatus;
        id: string;
        fullName: string;
        email: string;
        phone: string;
        countryCode: string | null;
        detectedCountryCode: string | null;
        phoneVerified: boolean;
        emailVerified: boolean;
    } | null>;
    getBlueprint(): {
        roles: string[];
        antiFraud: string[];
        protectedContactData: boolean;
    };
}
