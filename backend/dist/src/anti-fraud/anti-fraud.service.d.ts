import { PrismaService } from '../database/prisma/prisma.service';
type RiskSignal = {
    key: string;
    severity: 'low' | 'medium' | 'high';
    evidence: Record<string, unknown>;
};
export declare class AntiFraudService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    private phoneRegex;
    private emailRegex;
    private linkRegex;
    private directContactRegex;
    analyzeMessage(body: string): {
        sanitizedBody: string;
        riskStatus: "flagged" | "clean";
        flags: string[];
        containsPhone: boolean;
        containsEmail: boolean;
        containsExternalLink: boolean;
        containsDirectContactIntent: boolean;
    };
    createFlags(params: {
        userId?: string;
        shipmentId?: string;
        messageId?: string;
        flags: string[];
    }): Promise<void>;
    private createAutoFlagIfMissing;
    buildUserRiskSignals(userId: string): Promise<{
        riskScore: number;
        recommendedRiskLevel: string;
        recommendedAction: string;
        signals: RiskSignal[];
    }>;
    getUserRiskSummary(userId: string): Promise<{
        total: number;
        high: number;
        medium: number;
        low: number;
        riskScore: number;
        signals: RiskSignal[];
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
    listReviewQueue(requester: {
        sub: string;
        role: string;
    }): Promise<{
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
            signals: RiskSignal[];
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
    createManualFlag(params: {
        userId: string;
        actorId?: string;
        flagType: string;
        severity: 'low' | 'medium' | 'high';
        details?: Record<string, unknown>;
    }): Promise<{
        id: string;
        createdAt: Date;
        userId: string | null;
        shipmentId: string | null;
        messageId: string | null;
        flagType: string;
        severity: string;
        details: import("@prisma/client/runtime/library").JsonValue | null;
    }>;
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
}
export {};
