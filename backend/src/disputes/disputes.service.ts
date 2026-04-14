import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ShipmentStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { runtimeObservability } from '../common/observability/runtime-observability';

@Injectable()
export class DisputesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(payload: { shipmentId: string; reason: string; context?: string }, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: payload.shipmentId },
      include: { customer: true, assignedTraveler: true },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    const canOpen =
      requester.sub === shipment.customerId ||
      requester.sub === shipment.assignedTravelerId ||
      ['admin', 'support'].includes(requester.role);

    if (!canOpen) {
      throw new ForbiddenException('No puedes abrir una disputa para este envío.');
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
      data: { status: ShipmentStatus.disputed },
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

    const notifyTargets = [shipment.customerId, shipment.assignedTravelerId].filter(
      (id): id is string => Boolean(id && id !== requester.sub),
    );
    if (notifyTargets.length > 0) {
      await this.notificationsService.sendPushMany(
        notifyTargets,
        'Se abrió una disputa',
        `El envío ${payload.shipmentId} entró en revisión operativa.`,
        'dispute_opened',
        payload.shipmentId,
      );
    }

    runtimeObservability.recordBusinessEvent({
      type: 'dispute_opened',
      entityId: dispute.id,
      actorId: requester.sub,
      shipmentId: payload.shipmentId,
    });

    return dispute;
  }

  async listMine(requester: { sub: string; role: string }) {
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

  async getQueue(requester: { sub: string; role: string }) {
    if (!['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('Solo admin o soporte puede ver la cola de disputas.');
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

  async resolve(disputeId: string, payload: { status: 'resolved' | 'rejected' | 'escalated'; resolution?: string }, requester: { sub: string; role: string }) {
    if (!['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('Solo admin o soporte puede resolver disputas.');
    }

    const dispute = await this.prisma.dispute.findUnique({
      where: { id: disputeId },
      include: { shipment: true },
    });

    if (!dispute) {
      throw new NotFoundException('Disputa no encontrada.');
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
          status: dispute.shipment.assignedTravelerId ? ShipmentStatus.assigned : ShipmentStatus.offered,
        },
      });
    }

    await this.notificationsService.sendPushMany(
      [dispute.shipment.customerId, dispute.shipment.assignedTravelerId].filter(
        (id): id is string => Boolean(id),
      ),
      payload.status === 'resolved' ? 'Disputa resuelta' : payload.status === 'escalated' ? 'Disputa escalada' : 'Disputa cerrada',
      payload.resolution ?? `La disputa del envío ${dispute.shipmentId} fue actualizada a ${payload.status}.`,
      'dispute_updated',
      dispute.shipmentId,
    );

    runtimeObservability.recordBusinessEvent({
      type: `dispute_${payload.status}`,
      entityId: disputeId,
      actorId: requester.sub,
      shipmentId: dispute.shipmentId,
    });

    return updated;
  }
}
