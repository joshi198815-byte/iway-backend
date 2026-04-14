import { Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SubmitTransferDto } from './dto/submit-transfer.dto';
import { ReviewTransferDto } from './dto/review-transfer.dto';
import { CommissionsService } from '../commissions/commissions.service';
export declare class TransfersService {
    private readonly prisma;
    private readonly notificationsService;
    private readonly commissionsService;
    constructor(prisma: PrismaService, notificationsService: NotificationsService, commissionsService: CommissionsService);
    getPayoutPolicy(travelerId: string, requester?: {
        sub: string;
        role: string;
    }): Promise<{
        travelerId: string;
        status: import(".prisma/client").$Enums.TravelerStatus;
        kycTier: import(".prisma/client").$Enums.KycTier;
        trustScore: number;
        payoutHoldEnabled: boolean;
        policy: string;
        approvedTransfers: number;
        deliveredShipments: number;
        currentPendingAmount: number;
        maxAutoApprovalAmount: number;
        payoutDelayHours: number;
        reviewPriority: string;
        reasons: string[];
    }>;
    submit(travelerId: string, payload: SubmitTransferDto): Promise<{
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
    }>;
    getMyTransfers(travelerId: string): Promise<{
        transferredAmount: number;
        reviewAction: string | null;
        reviewReason: string | null;
        weeklySettlement: {
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
        } | null;
        payoutPolicy: {
            travelerId: string;
            status: import(".prisma/client").$Enums.TravelerStatus;
            kycTier: import(".prisma/client").$Enums.KycTier;
            trustScore: number;
            payoutHoldEnabled: boolean;
            policy: string;
            approvedTransfers: number;
            deliveredShipments: number;
            currentPendingAmount: number;
            maxAutoApprovalAmount: number;
            payoutDelayHours: number;
            reviewPriority: string;
            reasons: string[];
        };
        status: import(".prisma/client").$Enums.TransferStatus;
        id: string;
        createdAt: Date;
        travelerId: string;
        weeklySettlementId: string | null;
        bankReference: string | null;
        proofUrl: string | null;
        reviewedAt: Date | null;
        reviewedBy: string | null;
    }[]>;
    getReviewQueue(requester: {
        sub: string;
        role: string;
    }): Promise<{
        transferredAmount: number;
        weeklySettlement: {
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
        } | null;
        payoutPolicy: {
            travelerId: string;
            status: import(".prisma/client").$Enums.TravelerStatus;
            kycTier: import(".prisma/client").$Enums.KycTier;
            trustScore: number;
            payoutHoldEnabled: boolean;
            policy: string;
            approvedTransfers: number;
            deliveredShipments: number;
            currentPendingAmount: number;
            maxAutoApprovalAmount: number;
            payoutDelayHours: number;
            reviewPriority: string;
            reasons: string[];
        } | null;
        traveler: {
            travelerProfile: {
                trustScore: number;
                payoutHoldEnabled: boolean;
                kycTier: import(".prisma/client").$Enums.KycTier;
            } | null;
            fullName: string;
            email: string;
        };
        status: import(".prisma/client").$Enums.TransferStatus;
        id: string;
        createdAt: Date;
        travelerId: string;
        weeklySettlementId: string | null;
        bankReference: string | null;
        proofUrl: string | null;
        reviewedAt: Date | null;
        reviewedBy: string | null;
    }[]>;
    reviewTransfer(transferId: string, payload: ReviewTransferDto, requester: {
        sub: string;
        role: string;
    }): Promise<{
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
    } | {
        approved: {
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
        paidIds: string[];
        remaining: number;
        currentDebt: number;
    }>;
}
