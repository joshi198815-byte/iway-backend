import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterCustomerDto } from './dto/register-customer.dto';
import { RegisterTravelerAuthDto } from './dto/register-traveler-auth.dto';
import { RequestVerificationCodeDto } from './dto/request-verification-code.dto';
import { VerifyContactCodeDto } from './dto/verify-contact-code.dto';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    registerCustomer(body: RegisterCustomerDto): Promise<{
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
    registerTraveler(body: RegisterTravelerAuthDto): Promise<{
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
    login(body: LoginDto): Promise<{
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
    requestVerificationCode(body: RequestVerificationCodeDto, req: any): Promise<{
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
    verifyContact(body: VerifyContactCodeDto, req: any): Promise<{
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
    me(req: any): Promise<{
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
}
