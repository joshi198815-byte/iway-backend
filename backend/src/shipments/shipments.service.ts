import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ShipmentStatus, TravelerStatus } from '@prisma/client';
import { CommissionsService } from '../commissions/commissions.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { GeoService } from '../geo/geo.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { CreateShipmentDto } from './dto/create-shipment.dto';
import { UpdateShipmentStatusDto } from './dto/update-shipment-status.dto';

@Injectable()
export class ShipmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly geoService: GeoService,
    private readonly commissionsService: CommissionsService,
    private readonly notificationsService: NotificationsService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

  private normalizeDecimal(value: unknown) {
    const parsed = Number(value ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private async getTravelerWorkspace(userId: string) {
    const latestWorkspace = await this.prisma.auditLog.findFirst({
      where: {
        entityType: 'traveler_workspace',
        entityId: userId,
        action: 'traveler_workspace_updated',
      },
      orderBy: { createdAt: 'desc' },
    });

    const payload = latestWorkspace?.payload as Record<string, unknown> | null | undefined;
    const routes = Array.isArray(payload?.routes)
      ? [...new Set(payload!.routes
          .map((item) => item?.toString().trim().toLowerCase())
          .filter((item): item is string => Boolean(item && item.length > 0)))]
      : [];

    return {
      isOnline: payload?.isOnline !== false,
      routes,
    };
  }

  private buildStatusLabel(status: ShipmentStatus) {
    switch (status) {
      case ShipmentStatus.assigned:
        return 'asignado';
      case ShipmentStatus.picked_up:
        return 'recogido';
      case ShipmentStatus.in_transit:
        return 'en ruta';
      case ShipmentStatus.arrived:
        return 'arribó';
      case ShipmentStatus.delivered:
        return 'entregado';
      case ShipmentStatus.offered:
        return 'con ofertas';
      case ShipmentStatus.pending:
        return 'pendiente';
      default:
        return status;
    }
  }

  private async executeShipmentStatusTransition(params: {
    shipmentId: string;
    previousStatus: ShipmentStatus;
    nextStatus: ShipmentStatus;
    audience: Array<string | null | undefined>;
    actorId?: string;
    title?: string;
    body?: string;
    notificationType?: string;
  }) {
    const updatedShipment = await this.prisma.shipment.update({
      where: { id: params.shipmentId },
      data: { status: params.nextStatus },
    });

    await this.prisma.shipmentEvent.create({
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

    const audience = [...new Set(params.audience.filter(
      (userId): userId is string => Boolean(userId && userId.trim().length > 0),
    ))];

    this.realtimeGateway.emitShipmentStatusChanged(
      params.shipmentId,
      {
        shipmentId: params.shipmentId,
        previousStatus: params.previousStatus,
        nextStatus: params.nextStatus,
      },
      audience,
    );

    if (audience.length > 0) {
      await Promise.all(
        audience.map((userId) =>
          this.notificationsService.sendPush(
            userId,
            params.title ?? 'Estado del envío actualizado',
            params.body ?? `El envío ${params.shipmentId} ahora está ${this.buildStatusLabel(params.nextStatus)}.`,
            params.notificationType
              ?? (params.nextStatus === ShipmentStatus.delivered ? 'shipment_delivered' : 'shipment_status_changed'),
            params.shipmentId,
          ),
        ),
      );
    }

    return updatedShipment;
  }

  async create(payload: CreateShipmentDto) {
    const direction = this.geoService.resolveDirection(
      payload.originCountryCode,
      payload.destinationCountryCode,
    );

    if (!direction) {
      throw new BadRequestException('Solo se permiten rutas Guatemala ↔ USA.');
    }

    if (!payload.customerId) {
      throw new BadRequestException('No se pudo identificar al cliente autenticado.');
    }

    const customer = await this.prisma.user.findUnique({
      where: { id: payload.customerId },
      select: { id: true, role: true },
    });

    if (!customer || customer.role !== 'customer') {
      throw new BadRequestException('No se pudo identificar al cliente autenticado.');
    }

    const shipment = await this.prisma.shipment.create({
      data: {
        customerId: payload.customerId,
        status: ShipmentStatus.pending,
        direction,
        originCountryCode: payload.originCountryCode.toUpperCase(),
        destinationCountryCode: payload.destinationCountryCode.toUpperCase(),
        packageType: payload.packageType,
        packageCategory: payload.packageCategory,
        description: payload.description,
        declaredValue: payload.declaredValue,
        weightLb: payload.weightLb,
        senderName: payload.senderName,
        senderPhone: payload.senderPhone,
        senderAddress: payload.senderAddress,
        senderStateRegion: payload.senderStateRegion,
        receiverName: payload.receiverName,
        receiverPhone: payload.receiverPhone,
        receiverAddress: payload.receiverAddress,
        pickupLat: payload.pickupLat,
        pickupLng: payload.pickupLng,
        deliveryLat: payload.deliveryLat,
        deliveryLng: payload.deliveryLng,
        insuranceEnabled: payload.insuranceEnabled,
      },
      include: {
        images: true,
      },
    });

    const eligibleTravelers = await this.prisma.travelerProfile.findMany({
      where: {
        status: TravelerStatus.verified,
      },
      select: {
        userId: true,
      },
    });

    await this.notificationsService.sendPushMany(
      eligibleTravelers.map((item) => item.userId),
      'Nuevo envío disponible',
      `Hay un envío ${payload.originCountryCode.toUpperCase()} → ${payload.destinationCountryCode.toUpperCase()} esperando ofertas.`,
      'shipment_published',
      shipment.id,
    );

    return shipment;
  }

  async findAvailableForTraveler(travelerId: string, role: string) {
    if (role !== 'traveler') {
      throw new ForbiddenException('Solo los viajeros pueden ver oportunidades disponibles.');
    }

    const travelerProfile = await this.prisma.travelerProfile.findUnique({
      where: { userId: travelerId },
      include: { routes: { where: { active: true } } },
    });

    if (!travelerProfile) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    if (
      travelerProfile.status === TravelerStatus.blocked ||
      travelerProfile.status === TravelerStatus.blocked_for_debt ||
      travelerProfile.status === TravelerStatus.rejected
    ) {
      return [];
    }

    await this.getTravelerWorkspace(travelerId);

    const shipments = await this.prisma.shipment.findMany({
      where: {
        status: { in: [ShipmentStatus.pending, ShipmentStatus.offered] },
        assignedTravelerId: null,
        customerId: { not: travelerId },
        offers: {
          none: {
            travelerId,
            status: { in: ['pending', 'accepted'] },
          },
        },
      },
      include: {
        offers: {
          select: {
            travelerId: true,
            status: true,
            price: true,
          },
        },
        images: true,
        customer: {
          select: {
            fullName: true,
            receivedRatings: {
              select: {
                stars: true,
              },
            },
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }],
    });

    return shipments
      .map((shipment) => {
        const offerCount = shipment.offers.length;
        const minOfferPrice = offerCount > 0
          ? Math.min(...shipment.offers.map((offer) => this.normalizeDecimal(offer.price)))
          : 0;
        const declaredValue = this.normalizeDecimal(shipment.declaredValue);
        const weightLb = this.normalizeDecimal(shipment.weightLb);

        let score = 55;
        if (travelerProfile.status === TravelerStatus.verified) score += 10;
        if ((travelerProfile.verificationScore ?? 0) >= 80) score += 10;
        else if ((travelerProfile.verificationScore ?? 0) >= 65) score += 6;
        const currentDebt = this.normalizeDecimal(travelerProfile.currentDebt);
        if (currentDebt > 0) score -= Math.min(10, currentDebt / 20);
        if (offerCount === 0) score += 10;
        else if (offerCount <= 2) score += 4;
        if (declaredValue >= 250) score += 6;
        if (weightLb > 0 && weightLb <= 15) score += 4;
        if (shipment.insuranceEnabled) score += 3;

        score = Math.max(1, Math.min(100, Math.round(score)));

        const pickupRegion = (shipment as { senderStateRegion?: string | null }).senderStateRegion?.trim() || 'sin departamento confirmado';
        const insights = [
          'Oportunidad disponible para tu operación',
          `Recogida en ${pickupRegion}`,
          offerCount === 0 ? 'Sin competencia todavía' : `${offerCount} oferta${offerCount === 1 ? '' : 's'} activa${offerCount === 1 ? '' : 's'}`,
          minOfferPrice > 0 ? `Oferta más baja actual: $${minOfferPrice.toFixed(2)}` : 'Aún no hay ofertas registradas',
          shipment.insuranceEnabled ? 'Incluye seguro declarado' : 'Sin seguro adicional',
        ];

        const customerScores = shipment.customer?.receivedRatings?.map((rating) => this.normalizeDecimal(rating.stars)) ?? [];
        const customerRatingAvg = customerScores.length > 0
          ? customerScores.reduce((sum, score) => sum + score, 0) / customerScores.length
          : 0;

        return {
          ...shipment,
          customerName: shipment.customer?.fullName ?? 'Cliente i-Way',
          customerRatingAvg,
          offerCount,
          marketplaceScore: score,
          marketplaceTier: score >= 80 ? 'prime' : score >= 65 ? 'strong' : 'watch',
          marketplaceInsights: insights,
        };
      })
      .sort((a, b) => b.marketplaceScore - a.marketplaceScore);
  }

  async findAll() {
    return this.prisma.shipment.findMany({
      include: {
        offers: true,
        commission: true,
        customer: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            status: true,
          },
        },
        assignedTraveler: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            status: true,
          },
        },
        images: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }


  async findMine(requester: { sub: string; role: string }) {
    const where = requester.role === 'traveler'
      ? { assignedTravelerId: requester.sub }
      : { customerId: requester.sub };

    return this.prisma.shipment.findMany({
      where,
      include: {
        offers: true,
        commission: true,
        customer: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            status: true,
          },
        },
        assignedTraveler: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            status: true,
          },
        },
        images: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  private ensureShipmentAccess(
    shipment: { customerId: string; assignedTravelerId: string | null },
    requester: { sub: string; role: string },
  ) {
    const isPrivileged = ['admin', 'support'].includes(requester.role);
    const isParticipant = shipment.customerId === requester.sub || shipment.assignedTravelerId === requester.sub;

    if (!isPrivileged && !isParticipant) {
      throw new ForbiddenException('No tienes acceso a este envío.');
    }
  }

  async findOne(id: string, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id },
      include: {
        offers: true,
        events: true,
        commission: true,
        customer: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            status: true,
          },
        },
        assignedTraveler: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            status: true,
          },
        },
        images: true,
      },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    this.ensureShipmentAccess(shipment, requester);

    return shipment;
  }

  async updateStatus(id: string, payload: UpdateShipmentStatusDto, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id },
      include: {
        customer: {
          select: { id: true, fullName: true },
        },
        assignedTraveler: {
          select: { id: true, fullName: true },
        },
      },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    const openDispute = await this.prisma.dispute.findFirst({
      where: {
        shipmentId: id,
        status: { in: ['open', 'escalated'] },
      },
      select: { id: true },
    });

    if (openDispute) {
      throw new ForbiddenException('Este envío tiene una disputa abierta y no puede avanzar hasta resolverse.');
    }

    const isPrivileged = ['admin', 'support'].includes(requester.role);
    const isAssignedTraveler = shipment.assignedTravelerId === requester.sub;

    if (!isPrivileged) {
      const travelerAllowedStatuses: ShipmentStatus[] = [
        ShipmentStatus.picked_up,
        ShipmentStatus.in_transit,
        ShipmentStatus.arrived,
        ShipmentStatus.delivered,
      ];

      if (!isAssignedTraveler || !travelerAllowedStatuses.includes(payload.status)) {
        throw new ForbiddenException('No tienes permiso para actualizar este estado.');
      }
    }

    const updated = await this.executeShipmentStatusTransition({
      shipmentId: id,
      previousStatus: shipment.status,
      nextStatus: payload.status,
      audience: [shipment.customerId, shipment.assignedTravelerId],
      actorId: requester.sub,
    });

    if (payload.status === ShipmentStatus.delivered && payload.imageUrls?.length) {
      await this.prisma.shipmentImage.createMany({
        data: payload.imageUrls.map((imageUrl) => ({
          shipmentId: id,
          imageUrl,
          kind: 'delivery_proof',
        })),
      });
    }

    if (payload.status === ShipmentStatus.delivered) {
      await this.commissionsService.createCommissionForDeliveredShipment(updated);
    }

    return this.prisma.shipment.findUnique({
      where: { id },
      include: {
        customer: true,
        assignedTraveler: true,
        offers: true,
        events: true,
        commission: true,
      },
    });
  }
}
