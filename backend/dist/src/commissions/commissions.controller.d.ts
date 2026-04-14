import { CommissionsService } from './commissions.service';
import { RegisterCommissionPaymentDto } from './dto/register-commission-payment.dto';
import { RunWeeklyCutoffDto } from './dto/run-weekly-cutoff.dto';
import { UpdatePricingSettingsDto } from './dto/update-pricing-settings.dto';
import { UpdateCutoffPreferenceDto } from './dto/update-cutoff-preference.dto';
import { CreateLedgerAdjustmentDto } from './dto/create-ledger-adjustment.dto';
export declare class CommissionsController {
    private readonly commissionsService;
    constructor(commissionsService: CommissionsService);
    registerPayment(body: RegisterCommissionPaymentDto, req: any): Promise<{
        transfer: {
            status: import(".prisma/client").$Enums.TransferStatus;
            id: string;
            createdAt: Date;
            travelerId: string;
            weeklySettlementId: string | null;
            bankReference: string | null;
            transferredAmount: import("@prisma/client/runtime/library").Decimal;
            proofUrl: string | null;
            reviewedAt: Date | null;
            reviewedBy: string | null;
        };
        totalPending: number;
        autoReleased: boolean;
    }>;
    runWeeklyCutoff(body: RunWeeklyCutoffDto, req: any): Promise<{
        processedCommissions: number;
        blockedTravelers: number;
        runDate: Date;
    }>;
    getMyCutoffPreference(req: any): Promise<{
        preferredCutoffDay: number;
        preferredCutoffLabel: string;
    }>;
    updateMyCutoffPreference(body: UpdateCutoffPreferenceDto, req: any): Promise<{
        preferredCutoffDay: number;
        preferredCutoffLabel: string;
    }>;
    getMyLedger(req: any): Promise<{
        travelerId: string;
        currentDebt: number;
        preferredCutoffDay: number;
        preferredCutoffLabel: string;
        entries: {
            amount: number;
            balanceAfter: number | null;
            status: import(".prisma/client").$Enums.LedgerEntryStatus;
            id: string;
            createdAt: Date;
            description: string;
            direction: import(".prisma/client").$Enums.LedgerEntryDirection;
            kind: import(".prisma/client").$Enums.LedgerEntryKind;
            travelerId: string;
            metadata: import("@prisma/client/runtime/library").JsonValue | null;
            occurredAt: Date;
            createdBy: string | null;
            weeklySettlementId: string | null;
            commissionId: string | null;
            transferId: string | null;
        }[];
    }>;
    getTravelerSummary(travelerId: string, req: any): Promise<{
        travelerId: string;
        totalPending: number;
        currentDebt: number;
        travelerStatus: import(".prisma/client").$Enums.TravelerStatus;
        preferredCutoffDay: number;
        preferredCutoffLabel: string;
        pricingSettings: {
            commissionPerLb: number;
            groundCommissionPercent: number;
        };
        recentTransfers: {
            transferredAmount: number;
            status: import(".prisma/client").$Enums.TransferStatus;
            id: string;
            createdAt: Date;
            travelerId: string;
            weeklySettlementId: string | null;
            bankReference: string | null;
            proofUrl: string | null;
            reviewedAt: Date | null;
            reviewedBy: string | null;
        }[];
        settlements: {
            totalCommission: number;
            totalPaid: number;
            totalPending: number;
            id: string;
            createdAt: Date;
            updatedAt: Date;
            travelerId: string;
            dueDate: Date;
            weekStart: Date;
            weekEnd: Date;
            isOverdue: boolean;
            isBlocked: boolean;
        }[];
        ledger: {
            amount: number;
            balanceAfter: number | null;
            status: import(".prisma/client").$Enums.LedgerEntryStatus;
            id: string;
            createdAt: Date;
            description: string;
            direction: import(".prisma/client").$Enums.LedgerEntryDirection;
            kind: import(".prisma/client").$Enums.LedgerEntryKind;
            travelerId: string;
            metadata: import("@prisma/client/runtime/library").JsonValue | null;
            occurredAt: Date;
            createdBy: string | null;
            weeklySettlementId: string | null;
            commissionId: string | null;
            transferId: string | null;
        }[];
        commissions: {
            commissionAmount: number;
            ruleType: string;
            calculationBase: number;
            appliedRate: number;
            shipment: {
                originCountryCode: string;
                destinationCountryCode: string;
                packageType: string;
                declaredValue: import("@prisma/client/runtime/library").Decimal;
                weightLb: import("@prisma/client/runtime/library").Decimal | null;
            };
            status: import(".prisma/client").$Enums.CommissionStatus;
            id: string;
            shipmentId: string;
            travelerId: string;
            generatedAt: Date;
            dueDate: Date | null;
            paidAt: Date | null;
            settlementWeek: Date | null;
            notes: string | null;
        }[];
    }>;
    getTravelerLedger(travelerId: string, req: any): Promise<{
        travelerId: string;
        currentDebt: number;
        preferredCutoffDay: number;
        preferredCutoffLabel: string;
        entries: {
            amount: number;
            balanceAfter: number | null;
            status: import(".prisma/client").$Enums.LedgerEntryStatus;
            id: string;
            createdAt: Date;
            description: string;
            direction: import(".prisma/client").$Enums.LedgerEntryDirection;
            kind: import(".prisma/client").$Enums.LedgerEntryKind;
            travelerId: string;
            metadata: import("@prisma/client/runtime/library").JsonValue | null;
            occurredAt: Date;
            createdBy: string | null;
            weeklySettlementId: string | null;
            commissionId: string | null;
            transferId: string | null;
        }[];
    }>;
    createLedgerAdjustment(travelerId: string, body: CreateLedgerAdjustmentDto, req: any): Promise<{
        entry: {
            amount: number;
            balanceAfter: number | null;
            status: import(".prisma/client").$Enums.LedgerEntryStatus;
            id: string;
            createdAt: Date;
            description: string;
            direction: import(".prisma/client").$Enums.LedgerEntryDirection;
            kind: import(".prisma/client").$Enums.LedgerEntryKind;
            travelerId: string;
            metadata: import("@prisma/client/runtime/library").JsonValue | null;
            occurredAt: Date;
            createdBy: string | null;
            weeklySettlementId: string | null;
            commissionId: string | null;
            transferId: string | null;
        };
        currentDebt: number;
    }>;
    getPricingSettings(req: any): Promise<{
        commissionPerLb: number;
        groundCommissionPercent: number;
        history: {
            id: string;
            actorId: string | null;
            actorName: string | null;
            actorEmail: string | null;
            createdAt: Date;
            payload: import("@prisma/client/runtime/library").JsonValue;
        }[];
        id: string;
        createdAt: Date;
        updatedAt: Date;
    }>;
    updatePricingSettings(body: UpdatePricingSettingsDto, req: any): Promise<{
        commissionPerLb: number;
        groundCommissionPercent: number;
        history: {
            id: string;
            actorId: string | null;
            actorName: string | null;
            actorEmail: string | null;
            createdAt: Date;
            payload: import("@prisma/client/runtime/library").JsonValue;
        }[];
        id: string;
        createdAt: Date;
        updatedAt: Date;
    }>;
}
