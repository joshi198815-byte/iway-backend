import { Prisma, Shipment } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { RegisterCommissionPaymentDto } from './dto/register-commission-payment.dto';
export declare class CommissionsService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    private normalizeCutoffDay;
    private getIsoWeekday;
    private getUpcomingCutoff;
    private getSettlementWindow;
    private getCutoffDayLabel;
    private createLedgerEntry;
    getTravelerLedger(travelerId: string): Promise<{
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
            metadata: Prisma.JsonValue | null;
            occurredAt: Date;
            createdBy: string | null;
            weeklySettlementId: string | null;
            commissionId: string | null;
            transferId: string | null;
        }[];
    }>;
    private getPricingHistory;
    getPricingSettings(): Promise<{
        commissionPerLb: number;
        groundCommissionPercent: number;
        history: {
            id: string;
            actorId: string | null;
            actorName: string | null;
            actorEmail: string | null;
            createdAt: Date;
            payload: Prisma.JsonValue;
        }[];
        id: string;
        createdAt: Date;
        updatedAt: Date;
    }>;
    updatePricingSettings(commissionPerLb: number, groundCommissionPercent: number, actorId?: string): Promise<{
        commissionPerLb: number;
        groundCommissionPercent: number;
        history: {
            id: string;
            actorId: string | null;
            actorName: string | null;
            actorEmail: string | null;
            createdAt: Date;
            payload: Prisma.JsonValue;
        }[];
        id: string;
        createdAt: Date;
        updatedAt: Date;
    }>;
    calculateCommissionAmount(shipment: Shipment): Promise<number>;
    createCommissionForDeliveredShipment(shipment: Shipment): Promise<{
        status: import(".prisma/client").$Enums.CommissionStatus;
        id: string;
        shipmentId: string;
        travelerId: string;
        commissionAmount: Prisma.Decimal;
        generatedAt: Date;
        dueDate: Date | null;
        paidAt: Date | null;
        settlementWeek: Date | null;
        notes: string | null;
    } | null>;
    upsertWeeklySettlement(travelerId: string, baseDate: Date): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        travelerId: string;
        dueDate: Date;
        weekStart: Date;
        weekEnd: Date;
        totalCommission: Prisma.Decimal;
        totalPaid: Prisma.Decimal;
        totalPending: Prisma.Decimal;
        isOverdue: boolean;
        isBlocked: boolean;
    }>;
    registerPayment(payload: RegisterCommissionPaymentDto): Promise<{
        transfer: {
            status: import(".prisma/client").$Enums.TransferStatus;
            id: string;
            createdAt: Date;
            travelerId: string;
            weeklySettlementId: string | null;
            bankReference: string | null;
            transferredAmount: Prisma.Decimal;
            proofUrl: string | null;
            reviewedAt: Date | null;
            reviewedBy: string | null;
        };
        totalPending: number;
        autoReleased: boolean;
    }>;
    runWeeklyCutoff(runDateIso?: string): Promise<{
        processedCommissions: number;
        blockedTravelers: number;
        runDate: Date;
    }>;
    getTravelerSummary(travelerId: string): Promise<{
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
            metadata: Prisma.JsonValue | null;
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
                declaredValue: Prisma.Decimal;
                weightLb: Prisma.Decimal | null;
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
    createManualAdjustment(travelerId: string, payload: {
        direction: 'debit' | 'credit';
        amount: number;
        description: string;
        weeklySettlementId?: string;
    }, requester: {
        sub: string;
        role: string;
    }): Promise<{
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
            metadata: Prisma.JsonValue | null;
            occurredAt: Date;
            createdBy: string | null;
            weeklySettlementId: string | null;
            commissionId: string | null;
            transferId: string | null;
        };
        currentDebt: number;
    }>;
    recordApprovedTransferLedger(params: {
        travelerId: string;
        transferId: string;
        weeklySettlementId?: string | null;
        amount: number;
        balanceAfter: number;
        createdBy?: string;
        metadata?: Record<string, unknown>;
    }): Promise<{
        status: import(".prisma/client").$Enums.LedgerEntryStatus;
        id: string;
        createdAt: Date;
        description: string;
        direction: import(".prisma/client").$Enums.LedgerEntryDirection;
        kind: import(".prisma/client").$Enums.LedgerEntryKind;
        travelerId: string;
        amount: Prisma.Decimal;
        balanceAfter: Prisma.Decimal | null;
        metadata: Prisma.JsonValue | null;
        occurredAt: Date;
        createdBy: string | null;
        weeklySettlementId: string | null;
        commissionId: string | null;
        transferId: string | null;
    }>;
    updateTravelerCutoffPreference(travelerId: string, preferredCutoffDay: number): Promise<{
        preferredCutoffDay: number;
        preferredCutoffLabel: string;
    }>;
    getTravelerCutoffPreference(travelerId: string): Promise<{
        preferredCutoffDay: number;
        preferredCutoffLabel: string;
    }>;
}
