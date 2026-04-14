"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TransfersService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../database/prisma/prisma.service");
const notifications_service_1 = require("../notifications/notifications.service");
const runtime_observability_1 = require("../common/observability/runtime-observability");
const commissions_service_1 = require("../commissions/commissions.service");
let TransfersService = class TransfersService {
    constructor(prisma, notificationsService, commissionsService) {
        this.prisma = prisma;
        this.notificationsService = notificationsService;
        this.commissionsService = commissionsService;
    }
    async getPayoutPolicy(travelerId, requester) {
        if (requester && requester.sub !== travelerId && !['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('No tienes acceso a esta política de payout.');
        }
        const traveler = await this.prisma.travelerProfile.findUnique({
            where: { userId: travelerId },
            include: { user: true },
        });
        if (!traveler) {
            throw new common_1.NotFoundException('Perfil de viajero no encontrado.');
        }
        const [approvedTransfers, deliveredShipments, pendingAmount] = await Promise.all([
            this.prisma.transferPayment.count({ where: { travelerId, status: client_1.TransferStatus.approved } }),
            this.prisma.shipment.count({ where: { assignedTravelerId: travelerId, status: 'delivered' } }),
            this.prisma.weeklySettlement.aggregate({
                where: { travelerId },
                _sum: { totalPending: true },
            }),
        ]);
        const trustScore = traveler.trustScore ?? 0;
        const pendingUsd = Number(pendingAmount._sum.totalPending ?? 0);
        const holdReasons = [];
        if (traveler.payoutHoldEnabled)
            holdReasons.push('Hold operativo activo');
        if (trustScore < 55)
            holdReasons.push('Trust score insuficiente');
        if (traveler.status !== client_1.TravelerStatus.verified)
            holdReasons.push('Traveler no verificado');
        let policy = 'manual_review';
        let maxAutoApprovalAmount = 0;
        let payoutDelayHours = 48;
        if (holdReasons.length > 0) {
            policy = 'hold';
            payoutDelayHours = 72;
        }
        else if (traveler.kycTier === 'premium' && trustScore >= 85 && approvedTransfers >= 3) {
            policy = 'fast_track';
            maxAutoApprovalAmount = 450;
            payoutDelayHours = 6;
        }
        else if ((traveler.kycTier === 'premium' || traveler.kycTier === 'enhanced') && trustScore >= 65) {
            policy = 'monitored';
            maxAutoApprovalAmount = 220;
            payoutDelayHours = 24;
        }
        return {
            travelerId,
            status: traveler.status,
            kycTier: traveler.kycTier,
            trustScore,
            payoutHoldEnabled: traveler.payoutHoldEnabled,
            policy,
            approvedTransfers,
            deliveredShipments,
            currentPendingAmount: pendingUsd,
            maxAutoApprovalAmount,
            payoutDelayHours,
            reviewPriority: policy === 'hold' ? 'critical' : policy === 'manual_review' ? 'high' : policy === 'monitored' ? 'medium' : 'low',
            reasons: holdReasons.length > 0
                ? holdReasons
                : policy === 'fast_track'
                    ? ['Traveler premium con buen trust y historial aprobado']
                    : policy === 'monitored'
                        ? ['Traveler elegible con monitoreo reforzado']
                        : ['Transferencias requieren revisión manual'],
        };
    }
    async submit(travelerId, payload) {
        const traveler = await this.prisma.travelerProfile.findUnique({
            where: { userId: travelerId },
            select: { userId: true, payoutHoldEnabled: true, status: true, trustScore: true },
        });
        if (!traveler) {
            throw new common_1.NotFoundException('Perfil de viajero no encontrado.');
        }
        const payoutPolicy = await this.getPayoutPolicy(travelerId);
        if (traveler.status !== client_1.TravelerStatus.verified) {
            throw new common_1.ForbiddenException('Debes completar tu verificación antes de reportar pagos operativos.');
        }
        if (payoutPolicy.policy === 'hold') {
            throw new common_1.ForbiddenException('Tu cuenta tiene una retención operativa activa. Contacta soporte para completar la revisión KYC.');
        }
        if (payload.weeklySettlementId) {
            const settlement = await this.prisma.weeklySettlement.findUnique({
                where: { id: payload.weeklySettlementId },
                select: { travelerId: true },
            });
            if (!settlement || settlement.travelerId !== travelerId) {
                throw new common_1.ForbiddenException('Ese corte no pertenece al viajero actual.');
            }
        }
        const transfer = await this.prisma.transferPayment.create({
            data: {
                travelerId,
                weeklySettlementId: payload.weeklySettlementId,
                bankReference: payload.bankReference,
                transferredAmount: payload.amount,
                proofUrl: payload.proofUrl,
                status: client_1.TransferStatus.submitted,
            },
        });
        await this.prisma.auditLog.create({
            data: {
                actorId: travelerId,
                entityType: 'transfer_payment',
                entityId: transfer.id,
                action: 'transfer_submitted',
                payload: {
                    amount: payload.amount,
                    weeklySettlementId: payload.weeklySettlementId ?? null,
                    bankReference: payload.bankReference ?? null,
                    payoutPolicy,
                },
            },
        });
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'transfer_submitted',
            entityId: transfer.id,
            actorId: travelerId,
            metadata: {
                amount: Number(transfer.transferredAmount),
                weeklySettlementId: payload.weeklySettlementId ?? null,
            },
        });
        return transfer;
    }
    async getMyTransfers(travelerId) {
        const transfers = await this.prisma.transferPayment.findMany({
            where: { travelerId },
            orderBy: { createdAt: 'desc' },
            include: {
                weeklySettlement: true,
            },
            take: 30,
        });
        const auditLogs = await this.prisma.auditLog.findMany({
            where: {
                entityType: 'transfer_payment',
                entityId: { in: transfers.map((item) => item.id) },
                action: { in: ['transfer_approved', 'transfer_rejected'] },
            },
            orderBy: { createdAt: 'desc' },
        });
        const payoutPolicy = await this.getPayoutPolicy(travelerId);
        return transfers.map((item) => {
            const reviewLog = auditLogs.find((log) => log.entityId === item.id);
            const reviewPayload = reviewLog?.payload;
            return {
                ...item,
                transferredAmount: Number(item.transferredAmount),
                reviewAction: reviewLog?.action ?? null,
                reviewReason: typeof reviewPayload?.reason === 'string' ? reviewPayload.reason : null,
                weeklySettlement: item.weeklySettlement
                    ? {
                        ...item.weeklySettlement,
                        totalCommission: Number(item.weeklySettlement.totalCommission),
                        totalPaid: Number(item.weeklySettlement.totalPaid),
                        totalPending: Number(item.weeklySettlement.totalPending),
                    }
                    : null,
                payoutPolicy,
            };
        });
    }
    async getReviewQueue(requester) {
        if (!['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede revisar transferencias.');
        }
        const transfers = await this.prisma.transferPayment.findMany({
            where: { status: client_1.TransferStatus.submitted },
            include: {
                traveler: {
                    select: {
                        fullName: true,
                        email: true,
                        travelerProfile: {
                            select: { trustScore: true, payoutHoldEnabled: true, kycTier: true },
                        },
                    },
                },
                weeklySettlement: true,
            },
            orderBy: { createdAt: 'asc' },
            take: 100,
        });
        const policyEntries = await Promise.all(transfers.map(async (item) => ({
            transferId: item.id,
            payoutPolicy: await this.getPayoutPolicy(item.travelerId, requester),
        })));
        return transfers.map((item) => ({
            ...item,
            transferredAmount: Number(item.transferredAmount),
            weeklySettlement: item.weeklySettlement
                ? {
                    ...item.weeklySettlement,
                    totalCommission: Number(item.weeklySettlement.totalCommission),
                    totalPaid: Number(item.weeklySettlement.totalPaid),
                    totalPending: Number(item.weeklySettlement.totalPending),
                }
                : null,
            payoutPolicy: policyEntries.find((entry) => entry.transferId === item.id)?.payoutPolicy ?? null,
        }));
    }
    async reviewTransfer(transferId, payload, requester) {
        if (!['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede revisar transferencias.');
        }
        const transfer = await this.prisma.transferPayment.findUnique({
            where: { id: transferId },
            include: {
                weeklySettlement: true,
            },
        });
        if (!transfer) {
            throw new common_1.NotFoundException('Transferencia no encontrada.');
        }
        if (transfer.status !== client_1.TransferStatus.submitted) {
            throw new common_1.ForbiddenException('Esta transferencia ya fue revisada.');
        }
        if (payload.status === 'rejected') {
            const rejected = await this.prisma.transferPayment.update({
                where: { id: transferId },
                data: {
                    status: client_1.TransferStatus.rejected,
                    reviewedBy: requester.sub,
                    reviewedAt: new Date(),
                },
            });
            await this.prisma.auditLog.create({
                data: {
                    actorId: requester.sub,
                    entityType: 'transfer_payment',
                    entityId: transferId,
                    action: 'transfer_rejected',
                    payload: { reason: payload.reason ?? null },
                },
            });
            await this.notificationsService.sendPush(transfer.travelerId, 'Transferencia rechazada', payload.reason
                ? `Tu pago fue rechazado: ${payload.reason}`
                : 'Tu pago fue rechazado. Revisa el soporte y vuelve a intentarlo.', 'transfer_review');
            runtime_observability_1.runtimeObservability.recordBusinessEvent({
                type: 'transfer_rejected',
                entityId: transferId,
                actorId: requester.sub,
                metadata: { travelerId: transfer.travelerId, reason: payload.reason ?? null },
            });
            return rejected;
        }
        const applied = await this.prisma.$transaction(async (tx) => {
            const pendingCommissions = await tx.travelerCommission.findMany({
                where: {
                    travelerId: transfer.travelerId,
                    status: { in: [client_1.CommissionStatus.pending, client_1.CommissionStatus.due, client_1.CommissionStatus.overdue] },
                },
                orderBy: { generatedAt: 'asc' },
            });
            let remaining = Number(transfer.transferredAmount);
            const paidIds = [];
            for (const commission of pendingCommissions) {
                const amount = Number(commission.commissionAmount);
                if (remaining + 1e-9 < amount) {
                    break;
                }
                remaining -= amount;
                paidIds.push(commission.id);
            }
            if (paidIds.length > 0) {
                await tx.travelerCommission.updateMany({
                    where: { id: { in: paidIds } },
                    data: {
                        status: client_1.CommissionStatus.paid,
                        paidAt: new Date(),
                    },
                });
            }
            const approved = await tx.transferPayment.update({
                where: { id: transferId },
                data: {
                    status: client_1.TransferStatus.approved,
                    reviewedBy: requester.sub,
                    reviewedAt: new Date(),
                },
            });
            const aggregatePending = await tx.travelerCommission.aggregate({
                where: {
                    travelerId: transfer.travelerId,
                    status: { in: [client_1.CommissionStatus.pending, client_1.CommissionStatus.due, client_1.CommissionStatus.overdue] },
                },
                _sum: { commissionAmount: true },
            });
            const currentDebt = Number(aggregatePending._sum.commissionAmount ?? 0);
            await tx.travelerProfile.updateMany({
                where: { userId: transfer.travelerId },
                data: {
                    currentDebt,
                    status: currentDebt > 0 ? client_1.TravelerStatus.blocked_for_debt : client_1.TravelerStatus.verified,
                    blockedReason: currentDebt > 0 ? 'Comisiones pendientes por completar' : null,
                },
            });
            const settlements = await tx.weeklySettlement.findMany({
                where: { travelerId: transfer.travelerId },
                orderBy: { weekEnd: 'desc' },
            });
            let paidPool = Number(transfer.transferredAmount) - remaining;
            for (const settlement of settlements) {
                const settlementPending = Number(settlement.totalPending);
                const appliedToSettlement = Math.min(settlementPending, paidPool);
                if (appliedToSettlement <= 0)
                    continue;
                const nextPending = settlementPending - appliedToSettlement;
                await tx.weeklySettlement.update({
                    where: { id: settlement.id },
                    data: {
                        totalPaid: { increment: appliedToSettlement },
                        totalPending: nextPending,
                        isBlocked: nextPending > 0 && settlement.dueDate < new Date(),
                        isOverdue: nextPending > 0 && settlement.dueDate < new Date(),
                    },
                });
                paidPool -= appliedToSettlement;
            }
            await tx.auditLog.create({
                data: {
                    actorId: requester.sub,
                    entityType: 'transfer_payment',
                    entityId: transferId,
                    action: 'transfer_approved',
                    payload: {
                        reason: payload.reason ?? null,
                        transferredAmount: Number(transfer.transferredAmount),
                        appliedCommissionIds: paidIds,
                        unappliedRemainder: remaining,
                    },
                },
            });
            return { approved, paidIds, remaining, currentDebt };
        });
        await this.notificationsService.sendPush(transfer.travelerId, 'Transferencia aprobada', applied.currentDebt > 0
            ? 'Tu pago fue aprobado. Aplicamos el saldo posible y todavía queda deuda pendiente.'
            : 'Tu pago fue aprobado y tu deuda quedó al día.', 'transfer_review');
        await this.commissionsService.recordApprovedTransferLedger({
            travelerId: transfer.travelerId,
            transferId,
            weeklySettlementId: transfer.weeklySettlementId,
            amount: Number(transfer.transferredAmount) - applied.remaining,
            balanceAfter: applied.currentDebt,
            createdBy: requester.sub,
            metadata: {
                paidCommissionIds: applied.paidIds,
                unappliedRemainder: applied.remaining,
            },
        });
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'transfer_approved',
            entityId: transferId,
            actorId: requester.sub,
            metadata: {
                travelerId: transfer.travelerId,
                currentDebt: applied.currentDebt,
                paidCommissionIds: applied.paidIds,
            },
        });
        return applied;
    }
};
exports.TransfersService = TransfersService;
exports.TransfersService = TransfersService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notifications_service_1.NotificationsService,
        commissions_service_1.CommissionsService])
], TransfersService);
//# sourceMappingURL=transfers.service.js.map