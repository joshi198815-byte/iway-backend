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
exports.DisputesService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../database/prisma/prisma.service");
const notifications_service_1 = require("../notifications/notifications.service");
const runtime_observability_1 = require("../common/observability/runtime-observability");
let DisputesService = class DisputesService {
    constructor(prisma, notificationsService) {
        this.prisma = prisma;
        this.notificationsService = notificationsService;
    }
    async create(payload, requester) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: payload.shipmentId },
            include: { customer: true, assignedTraveler: true },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        const canOpen = requester.sub === shipment.customerId ||
            requester.sub === shipment.assignedTravelerId ||
            ['admin', 'support'].includes(requester.role);
        if (!canOpen) {
            throw new common_1.ForbiddenException('No puedes abrir una disputa para este envío.');
        }
        const dispute = await this.prisma.dispute.create({
            data: {
                shipmentId: payload.shipmentId,
                openedBy: requester.sub,
                reason: payload.reason,
                resolution: payload.context ?? null,
                status: 'open',
            },
            include: {
                shipment: true,
                opener: { select: { fullName: true, email: true } },
            },
        });
        await this.prisma.shipment.update({
            where: { id: payload.shipmentId },
            data: { status: client_1.ShipmentStatus.disputed },
        });
        await this.prisma.shipmentEvent.create({
            data: {
                shipmentId: payload.shipmentId,
                eventType: 'dispute_opened',
                createdBy: requester.sub,
                eventPayload: {
                    disputeId: dispute.id,
                    reason: payload.reason,
                    context: payload.context ?? null,
                },
            },
        });
        await this.prisma.auditLog.create({
            data: {
                actorId: requester.sub,
                entityType: 'dispute',
                entityId: dispute.id,
                action: 'dispute_opened',
                payload: {
                    shipmentId: payload.shipmentId,
                    reason: payload.reason,
                    context: payload.context ?? null,
                },
            },
        });
        const notifyTargets = [shipment.customerId, shipment.assignedTravelerId].filter((id) => Boolean(id && id !== requester.sub));
        if (notifyTargets.length > 0) {
            await this.notificationsService.sendPushMany(notifyTargets, 'Se abrió una disputa', `El envío ${payload.shipmentId} entró en revisión operativa.`, 'dispute_opened', payload.shipmentId);
        }
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'dispute_opened',
            entityId: dispute.id,
            actorId: requester.sub,
            shipmentId: payload.shipmentId,
        });
        return dispute;
    }
    async listMine(requester) {
        const disputes = await this.prisma.dispute.findMany({
            where: ['admin', 'support'].includes(requester.role)
                ? undefined
                : {
                    OR: [
                        { openedBy: requester.sub },
                        { shipment: { customerId: requester.sub } },
                        { shipment: { assignedTravelerId: requester.sub } },
                    ],
                },
            include: {
                shipment: true,
                opener: { select: { fullName: true, email: true } },
            },
            orderBy: { updatedAt: 'desc' },
            take: 100,
        });
        return disputes;
    }
    async getQueue(requester) {
        if (!['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede ver la cola de disputas.');
        }
        return this.prisma.dispute.findMany({
            where: { status: { in: ['open', 'escalated'] } },
            include: {
                shipment: true,
                opener: { select: { fullName: true, email: true } },
            },
            orderBy: [{ status: 'asc' }, { updatedAt: 'asc' }],
            take: 100,
        });
    }
    async resolve(disputeId, payload, requester) {
        if (!['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('Solo admin o soporte puede resolver disputas.');
        }
        const dispute = await this.prisma.dispute.findUnique({
            where: { id: disputeId },
            include: { shipment: true },
        });
        if (!dispute) {
            throw new common_1.NotFoundException('Disputa no encontrada.');
        }
        const updated = await this.prisma.dispute.update({
            where: { id: disputeId },
            data: {
                status: payload.status,
                resolution: payload.resolution ?? dispute.resolution,
            },
            include: {
                shipment: true,
                opener: { select: { fullName: true, email: true } },
            },
        });
        await this.prisma.auditLog.create({
            data: {
                actorId: requester.sub,
                entityType: 'dispute',
                entityId: disputeId,
                action: `dispute_${payload.status}`,
                payload: {
                    resolution: payload.resolution ?? null,
                    shipmentId: dispute.shipmentId,
                },
            },
        });
        await this.prisma.shipmentEvent.create({
            data: {
                shipmentId: dispute.shipmentId,
                eventType: `dispute_${payload.status}`,
                createdBy: requester.sub,
                eventPayload: {
                    disputeId,
                    resolution: payload.resolution ?? null,
                },
            },
        });
        if (payload.status === 'resolved' || payload.status === 'rejected') {
            await this.prisma.shipment.update({
                where: { id: dispute.shipmentId },
                data: {
                    status: dispute.shipment.assignedTravelerId ? client_1.ShipmentStatus.assigned : client_1.ShipmentStatus.offered,
                },
            });
        }
        await this.notificationsService.sendPushMany([dispute.shipment.customerId, dispute.shipment.assignedTravelerId].filter((id) => Boolean(id)), payload.status === 'resolved' ? 'Disputa resuelta' : payload.status === 'escalated' ? 'Disputa escalada' : 'Disputa cerrada', payload.resolution ?? `La disputa del envío ${dispute.shipmentId} fue actualizada a ${payload.status}.`, 'dispute_updated', dispute.shipmentId);
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: `dispute_${payload.status}`,
            entityId: disputeId,
            actorId: requester.sub,
            shipmentId: dispute.shipmentId,
        });
        return updated;
    }
};
exports.DisputesService = DisputesService;
exports.DisputesService = DisputesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notifications_service_1.NotificationsService])
], DisputesService);
//# sourceMappingURL=disputes.service.js.map