import { TravelersService } from './travelers.service';
import { RegisterTravelerDto } from './dto/register-traveler.dto';
import { ReviewTravelerDto } from './dto/review-traveler.dto';
import { UpdatePayoutHoldDto } from './dto/update-payout-hold.dto';
export declare class TravelersController {
    private readonly travelersService;
    constructor(travelersService: TravelersService);
    register(body: RegisterTravelerDto): {
        message: string;
        travelerType: import("../common/constants/traveler-types").TravelerType;
        detectedCountryCode: string | undefined;
    };
    getAllowedRoutes(travelerType: 'avion_ida_vuelta' | 'avion_tierra' | 'solo_tierra'): ("gt_to_us" | "us_to_gt")[];
    getMyVerificationSummary(req: any): Promise<{
        userId: string;
        travelerProfileId: string;
        currentStatus: import(".prisma/client").$Enums.TravelerStatus;
        score: number;
        trustScore: number;
        trustLevel: string;
        checks: {
            key: string;
            passed: boolean;
            weight: number;
        }[];
        flagsSummary: {
            high: number;
            medium: number;
            low: number;
            total: number;
        };
        recommendedDecision: string;
        blockedReason: string | null;
        recentFlags: {
            id: string;
            createdAt: Date;
            userId: string | null;
            shipmentId: string | null;
            messageId: string | null;
            flagType: string;
            severity: string;
            details: import("@prisma/client/runtime/library").JsonValue | null;
        }[];
        payoutHoldRecommended: boolean;
        payoutHoldEnabled: boolean;
        suggestedKycTier: "basic" | "enhanced" | "premium";
        currentKycTier: import(".prisma/client").$Enums.KycTier;
        missingRequirements: string[];
        nextSteps: string[];
        deviceTrust: {
            activeDevices: number;
            suspiciousDevices: number;
            averageTrustScore: number;
            lastSeenAt: Date;
        };
        kycAssets: {
            documentProtected: boolean;
            selfieProtected: boolean;
            filesAttached: number;
        };
        evidence: {
            documentUrl: string | null;
            selfieUrl: string | null;
        };
        kycChecks: {
            status: import(".prisma/client").$Enums.KycCheckStatus;
            id: string;
            createdAt: Date;
            updatedAt: Date;
            kind: import(".prisma/client").$Enums.KycCheckKind;
            details: import("@prisma/client/runtime/library").JsonValue | null;
            travelerProfileId: string;
            confidence: number;
            summary: string | null;
        }[];
    }>;
    getReviewQueue(req: any): Promise<{
        userId: string;
        travelerProfileId: string;
        fullName: string;
        email: string;
        status: import(".prisma/client").$Enums.TravelerStatus;
        verificationScore: number;
        trustScore: number;
        payoutHoldEnabled: boolean;
        kycTier: import(".prisma/client").$Enums.KycTier;
        summary: {
            userId: string;
            travelerProfileId: string;
            currentStatus: import(".prisma/client").$Enums.TravelerStatus;
            score: number;
            trustScore: number;
            trustLevel: string;
            checks: {
                key: string;
                passed: boolean;
                weight: number;
            }[];
            flagsSummary: {
                high: number;
                medium: number;
                low: number;
                total: number;
            };
            recommendedDecision: string;
            blockedReason: string | null;
            recentFlags: {
                id: string;
                createdAt: Date;
                userId: string | null;
                shipmentId: string | null;
                messageId: string | null;
                flagType: string;
                severity: string;
                details: import("@prisma/client/runtime/library").JsonValue | null;
            }[];
            payoutHoldRecommended: boolean;
            payoutHoldEnabled: boolean;
            suggestedKycTier: "basic" | "enhanced" | "premium";
            currentKycTier: import(".prisma/client").$Enums.KycTier;
            missingRequirements: string[];
            nextSteps: string[];
            deviceTrust: {
                activeDevices: number;
                suspiciousDevices: number;
                averageTrustScore: number;
                lastSeenAt: Date;
            };
            kycAssets: {
                documentProtected: boolean;
                selfieProtected: boolean;
                filesAttached: number;
            };
            evidence: {
                documentUrl: string | null;
                selfieUrl: string | null;
            };
            kycChecks: {
                status: import(".prisma/client").$Enums.KycCheckStatus;
                id: string;
                createdAt: Date;
                updatedAt: Date;
                kind: import(".prisma/client").$Enums.KycCheckKind;
                details: import("@prisma/client/runtime/library").JsonValue | null;
                travelerProfileId: string;
                confidence: number;
                summary: string | null;
            }[];
        };
    }[]>;
    runKycAnalysis(userId: string, req: any): Promise<{
        userId: string;
        travelerProfileId: string;
        currentStatus: import(".prisma/client").$Enums.TravelerStatus;
        score: number;
        trustScore: number;
        trustLevel: string;
        checks: {
            key: string;
            passed: boolean;
            weight: number;
        }[];
        flagsSummary: {
            high: number;
            medium: number;
            low: number;
            total: number;
        };
        recommendedDecision: string;
        blockedReason: string | null;
        recentFlags: {
            id: string;
            createdAt: Date;
            userId: string | null;
            shipmentId: string | null;
            messageId: string | null;
            flagType: string;
            severity: string;
            details: import("@prisma/client/runtime/library").JsonValue | null;
        }[];
        payoutHoldRecommended: boolean;
        payoutHoldEnabled: boolean;
        suggestedKycTier: "basic" | "enhanced" | "premium";
        currentKycTier: import(".prisma/client").$Enums.KycTier;
        missingRequirements: string[];
        nextSteps: string[];
        deviceTrust: {
            activeDevices: number;
            suspiciousDevices: number;
            averageTrustScore: number;
            lastSeenAt: Date;
        };
        kycAssets: {
            documentProtected: boolean;
            selfieProtected: boolean;
            filesAttached: number;
        };
        evidence: {
            documentUrl: string | null;
            selfieUrl: string | null;
        };
        kycChecks: {
            status: import(".prisma/client").$Enums.KycCheckStatus;
            id: string;
            createdAt: Date;
            updatedAt: Date;
            kind: import(".prisma/client").$Enums.KycCheckKind;
            details: import("@prisma/client/runtime/library").JsonValue | null;
            travelerProfileId: string;
            confidence: number;
            summary: string | null;
        }[];
    }>;
    updatePayoutHold(userId: string, body: UpdatePayoutHoldDto, req: any): Promise<{
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
    }>;
    reviewTraveler(userId: string, body: ReviewTravelerDto, req: any): Promise<{
        traveler: {
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
        summary: {
            userId: string;
            travelerProfileId: string;
            currentStatus: import(".prisma/client").$Enums.TravelerStatus;
            score: number;
            trustScore: number;
            trustLevel: string;
            checks: {
                key: string;
                passed: boolean;
                weight: number;
            }[];
            flagsSummary: {
                high: number;
                medium: number;
                low: number;
                total: number;
            };
            recommendedDecision: string;
            blockedReason: string | null;
            recentFlags: {
                id: string;
                createdAt: Date;
                userId: string | null;
                shipmentId: string | null;
                messageId: string | null;
                flagType: string;
                severity: string;
                details: import("@prisma/client/runtime/library").JsonValue | null;
            }[];
            payoutHoldRecommended: boolean;
            payoutHoldEnabled: boolean;
            suggestedKycTier: "basic" | "enhanced" | "premium";
            currentKycTier: import(".prisma/client").$Enums.KycTier;
            missingRequirements: string[];
            nextSteps: string[];
            deviceTrust: {
                activeDevices: number;
                suspiciousDevices: number;
                averageTrustScore: number;
                lastSeenAt: Date;
            };
            kycAssets: {
                documentProtected: boolean;
                selfieProtected: boolean;
                filesAttached: number;
            };
            evidence: {
                documentUrl: string | null;
                selfieUrl: string | null;
            };
            kycChecks: {
                status: import(".prisma/client").$Enums.KycCheckStatus;
                id: string;
                createdAt: Date;
                updatedAt: Date;
                kind: import(".prisma/client").$Enums.KycCheckKind;
                details: import("@prisma/client/runtime/library").JsonValue | null;
                travelerProfileId: string;
                confidence: number;
                summary: string | null;
            }[];
        };
    }>;
}
