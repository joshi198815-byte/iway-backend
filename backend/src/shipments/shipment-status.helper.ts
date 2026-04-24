import { ShipmentStatus, type Prisma } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

type ShipmentStatusTransitionParams = {
  shipmentId: string;
  previousStatus: ShipmentStatus;
  nextStatus: ShipmentStatus;
  actorId?: string;
  audience?: Array<string | null | undefined>;
  shipmentUpdateData?: Prisma.ShipmentUpdateInput;
};

type ShipmentStatusTransitionSideEffects = {
  notificationsService: NotificationsService;
  realtimeGateway: RealtimeGateway;
  shipmentId: string;
  previousStatus: ShipmentStatus;
  nextStatus: ShipmentStatus;
  audience?: Array<string | null | undefined>;
  notificationAudience?: Array<string | null | undefined>;
  title?: string;
  body?: string;
  notificationType?: string;
  highPriority?: boolean;
};

export function normalizeShipmentAudience(audience: Array<string | null | undefined> = []) {
  return [...new Set(audience.filter((userId): userId is string => Boolean(userId && userId.trim().length > 0)))];
}

export function buildShipmentStatusLabel(status: ShipmentStatus) {
  switch (status) {
    case ShipmentStatus.assigned:
      return 'asignado';
    case ShipmentStatus.picked_up:
      return 'recogido';
    case ShipmentStatus.in_transit:
      return 'en tránsito';
    case ShipmentStatus.in_delivery:
      return 'en entrega';
    case ShipmentStatus.arrived:
      return 'arribó';
    case ShipmentStatus.delivered:
      return 'entregado';
    case ShipmentStatus.offered:
      return 'con ofertas';
    case ShipmentStatus.published:
      return 'publicado';
    case ShipmentStatus.pending:
      return 'pendiente';
    case ShipmentStatus.disputed:
      return 'en disputa';
    case ShipmentStatus.cancelled:
      return 'cancelado';
    default:
      return status;
  }
}

export async function executeShipmentStatusTransition(
  tx: Prisma.TransactionClient,
  params: ShipmentStatusTransitionParams,
) {
  const updatedShipment = await tx.shipment.update({
    where: { id: params.shipmentId },
    data: {
      ...(params.shipmentUpdateData ?? {}),
      status: params.nextStatus,
    },
  });

  await tx.shipmentEvent.create({
    data: {
      shipmentId: params.shipmentId,
      eventType: `status_${params.nextStatus}`,
      createdBy: params.actorId,
      eventPayload: {
        previousStatus: params.previousStatus,
        nextStatus: params.nextStatus,
      },
    },
  });

  return {
    updatedShipment,
    shipmentId: params.shipmentId,
    previousStatus: params.previousStatus,
    nextStatus: params.nextStatus,
    audience: normalizeShipmentAudience(params.audience),
  };
}

export async function dispatchShipmentStatusTransitionSideEffects(
  params: ShipmentStatusTransitionSideEffects,
) {
  const audience = normalizeShipmentAudience(params.audience);

  params.realtimeGateway.emitShipmentStatusChanged(
    params.shipmentId,
    {
      shipmentId: params.shipmentId,
      previousStatus: params.previousStatus,
      nextStatus: params.nextStatus,
    },
    audience,
  );

  const notificationAudience = normalizeShipmentAudience(params.notificationAudience ?? audience);

  if (notificationAudience.length === 0) {
    return;
  }

  await Promise.all(
    notificationAudience.map((userId) =>
      params.notificationsService.sendPush(
        userId,
        params.title ?? 'Estado del envío actualizado',
        params.body ?? `El envío ${params.shipmentId} ahora está ${buildShipmentStatusLabel(params.nextStatus)}.`,
        params.notificationType
          ?? (params.nextStatus === ShipmentStatus.delivered ? 'shipment_delivered' : 'shipment_status_changed'),
        params.shipmentId,
        { highPriority: params.highPriority === true },
      ),
    ),
  );
}
