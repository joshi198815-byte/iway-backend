import { TravelerType } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateTravelerProfileDto } from './dto/create-traveler-profile.dto';
import { RegisterTravelerDto } from './dto/register-traveler.dto';
export declare class TravelersService {
    private readonly prisma;
    private readonly notificationsService;
    constructor(prisma: PrismaService, notificationsService: NotificationsService);
    private normalizeDecimal;
    getAllowedDirectionsByType(travelerType: TravelerType): ("gt_to_us" | "us_to_gt")[];
    createTravelerProfile(payload: CreateTravelerProfileDto): Promise<{
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
    }>;
    getVerificationSummary(userId: string, requester: {
        sub: string;
        role: string;
    }): Promise<{
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
    runKycAnalysis(userId: string, requester: {
        sub: string;
        role: string;
    }): Promise<{
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
    listReviewQueue(requester: {
        sub: string;
        role: string;
    }): Promise<{
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
    updatePayoutHold(userId: string, payload: {
        enabled: boolean;
        reason?: string;
    }, requester: {
        sub: string;
        role: string;
    }): Promise<{
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
    reviewTraveler(userId: string, payload: {
        action: 'approve' | 'reject' | 'block';
        reason?: string;
    }, requester: {
        sub: string;
        role: string;
    }): Promise<{
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
    register(payload: RegisterTravelerDto): {
        message: string;
        travelerType: import("../common/constants/traveler-types").TravelerType;
        detectedCountryCode: string | undefined;
    };
}
