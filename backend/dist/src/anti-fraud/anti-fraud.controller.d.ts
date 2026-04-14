import { AntiFraudService } from './anti-fraud.service';
import { CreateManualFlagDto } from './dto/create-manual-flag.dto';
export declare class AntiFraudController {
    private readonly antiFraudService;
    constructor(antiFraudService: AntiFraudService);
    getRules(): {
        protectedContactData: boolean;
        scansChatForPhones: boolean;
        scansChatForEmails: boolean;
        scansChatForLinks: boolean;
        scansDirectContactIntent: boolean;
        autoFlagsSuspiciousMessages: boolean;
        autoScansDuplicateDocuments: boolean;
        autoScansVelocitySpikes: boolean;
        autoScansCountryMismatch: boolean;
        autoScansDeviceSpread: boolean;
        masksSensitiveData: boolean;
    };
    getUserSummary(userId: string, req: any): Promise<{
        total: number;
        high: number;
        medium: number;
        low: number;
        riskScore: number;
        signals: {
            key: string;
            severity: "low" | "medium" | "high";
            evidence: Record<string, unknown>;
        }[];
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
        recommendedRiskLevel: string;
        recommendedAction: string;
    }>;
    getReviewQueue(req: any): Promise<{
        userId: string;
        fullName: string;
        email: string;
        travelerStatus: import(".prisma/client").$Enums.TravelerStatus | null;
        summary: {
            total: number;
            high: number;
            medium: number;
            low: number;
            riskScore: number;
            signals: {
                key: string;
                severity: "low" | "medium" | "high";
                evidence: Record<string, unknown>;
            }[];
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
            recommendedRiskLevel: string;
            recommendedAction: string;
        };
    }[]>;
    recomputeUserSummary(userId: string, req: any): Promise<{
        total: number;
        high: number;
        medium: number;
        low: number;
        riskScore: number;
        signals: {
            key: string;
            severity: "low" | "medium" | "high";
            evidence: Record<string, unknown>;
        }[];
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
        recommendedRiskLevel: string;
        recommendedAction: string;
    }>;
    createManualFlag(userId: string, body: CreateManualFlagDto, req: any): Promise<{
        id: string;
        createdAt: Date;
        userId: string | null;
        shipmentId: string | null;
        messageId: string | null;
        flagType: string;
        severity: string;
        details: import("@prisma/client/runtime/library").JsonValue | null;
    }>;
}
