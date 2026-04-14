import { UsersService } from './users.service';
export declare class UsersController {
    private readonly usersService;
    constructor(usersService: UsersService);
    getBlueprint(): {
        roles: string[];
        antiFraud: string[];
        protectedContactData: boolean;
    };
    getById(id: string): Promise<{
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
}
