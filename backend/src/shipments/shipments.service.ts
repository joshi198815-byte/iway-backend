import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { OfferStatus, ShipmentStatus, TravelerStatus } from '@prisma/client';
import { CommissionsService } from '../commissions/commissions.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { GeoService } from '../geo/geo.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { CreateShipmentDto } from './dto/create-shipment.dto';
import { UpdateShipmentStatusDto } from './dto/update-shipment-status.dto';
import {
  dispatchShipmentStatusTransitionSideEffects,
  executeShipmentStatusTransition,
} from './shipment-status.helper';

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

  private normalizeCountryCode(countryCode: string) {
    const normalized = countryCode.trim().toUpperCase();

    if (!['GT', 'US'].includes(normalized)) {
      throw new BadRequestException('originCountryCode y destinationCountryCode solo aceptan GT o US.');
    }

    return normalized as 'GT' | 'US';
  }

  private resolveDirection(originCountryCode: 'GT' | 'US', destinationCountryCode: 'GT' | 'US') {
    if (originCountryCode === destinationCountryCode) {
      throw new BadRequestException('La ruta debe ser entre GT y US.');
    }

    return originCountryCode === 'GT' ? 'gt_to_us' : 'us_to_gt';
  }

  async create(payload: CreateShipmentDto, customerId: string) {
    const originCountryCode = this.normalizeCountryCode(payload.originCountryCode);
    const destinationCountryCode = this.normalizeCountryCode(payload.destinationCountryCode);
    const direction = this.resolveDirection(originCountryCode, destinationCountryCode);
    const weightLb = this.normalizeDecimal(payload.weightLb);
    const declaredValue = this.normalizeDecimal(payload.declaredValue);

    if (weightLb <= 0) {
      throw new BadRequestException('weightLb debe ser mayor a 0.');
    }

    if (declaredValue < 0) {
      throw new BadRequestException('declaredValue no puede ser negativo.');
    }

    console.log('[FLOW]', 'create shipment', {
      customerId,
      originCountryCode,
      destinationCountryCode,
      weightLb,
      declaredValue,
    });

    const customer = await this.prisma.user.findUnique({
      where: { id: customerId },
      select: { id: true, role: true, phoneVerified: true },
    });

    if (!customer || customer.role !== 'customer') {
      throw new BadRequestException('No se pudo identificar al cliente autenticado.');
    }

    if (!customer.phoneVerified) {
      throw new ForbiddenException('Debes validar tu número de teléfono antes de crear un envío.');
    }

    const shipment = await this.prisma.shipment.create({
      data: {
        customerId,
        status: ShipmentStatus.pending,
        direction,
        originCountryCode,
        destinationCountryCode,
        packageType: payload.packageType,
        packageCategory: payload.packageCategory,
        description: payload.description,
        declaredValue,
        weightLb,
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
        routes: {
          some: {
            active: true,
            direction,
          },
        },
      },
      select: {
        userId: true,
      },
    });

    await this.notificationsService.sendPushMany(
      eligibleTravelers.map((item) => item.userId),
      'Nuevo envío disponible',
      `Hay un envío ${originCountryCode} → ${destinationCountryCode} esperando ofertas.`,
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

    const activeDirections = [...new Set(travelerProfile.routes.map((route) => route.direction))];

    const shipments = await this.prisma.shipment.findMany({
      where: {
        status: { in: [ShipmentStatus.pending, ShipmentStatus.offered] },
        assignedTravelerId: null,
        customerId: { not: travelerId },
        offers: {
          none: {
            travelerId,
            status: { in: [OfferStatus.pending, OfferStatus.accepted] },
          },
        },
      },
      include: {
        offers: {
          select: {
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
      take: 20,
    });

    return shipments
      .map((shipment) => {
        const offerCount = shipment.offers.length;
        const minOfferPrice = offerCount > 0
          ? Math.min(...shipment.offers.map((offer) => this.normalizeDecimal(offer.price)))
          : 0;
        const normalizedDeclaredValue = this.normalizeDecimal(shipment.declaredValue);
        const normalizedWeightLb = this.normalizeDecimal(shipment.weightLb);

        let score = 55;
        if (travelerProfile.status === TravelerStatus.verified) score += 10;
        if ((travelerProfile.verificationScore ?? 0) >= 80) score += 10;
        else if ((travelerProfile.verificationScore ?? 0) >= 65) score += 6;
        const currentDebt = this.normalizeDecimal(travelerProfile.currentDebt);
        if (currentDebt > 0) score -= Math.min(10, currentDebt / 20);
        if (offerCount === 0) score += 10;
        else if (offerCount <= 2) score += 4;
        if (normalizedDeclaredValue >= 250) score += 6;
        if (normalizedWeightLb > 0 && normalizedWeightLb <= 15) score += 4;
        if (shipment.insuranceEnabled) score += 3;

        score = Math.max(1, Math.min(100, Math.round(score)));

        const pickupRegion = shipment.senderStateRegion?.trim() || 'sin departamento confirmado';
        const insights = [
          activeDirections.includes(shipment.direction) ? 'Coincide con una de tus rutas activas' : 'Disponible aunque no coincida con tus rutas guardadas',
          `Recogida en ${pickupRegion}`,
          offerCount === 0 ? 'Sin competencia todavía' : `${offerCount} oferta${offerCount === 1 ? '' : 's'} activa${offerCount === 1 ? '' : 's'}`,
          minOfferPrice > 0 ? `Oferta más baja actual: $${minOfferPrice.toFixed(2)}` : 'Aún no hay ofertas registradas',
          shipment.insuranceEnabled ? 'Incluye seguro declarado' : 'Sin seguro adicional',
        ];

        const customerScores = shipment.customer?.receivedRatings?.map((rating) => this.normalizeDecimal(rating.stars)) ?? [];
        const customerRatingAvg = customerScores.length > 0
          ? customerScores.reduce((sum, currentScore) => sum + currentScore, 0) / customerScores.length
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
      select: {
        id: true,
        status: true,
        customerId: true,
        assignedTravelerId: true,
        packageType: true,
        packageCategory: true,
        description: true,
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
        ShipmentStatus.in_delivery,
        ShipmentStatus.arrived,
        ShipmentStatus.delivered,
      ];

      if (!isAssignedTraveler || !travelerAllowedStatuses.includes(payload.status)) {
        throw new ForbiddenException('No tienes permiso para actualizar este estado.');
      }
    }

    const transition = await this.prisma.$transaction(async (tx) => {
      const nextTransition = await executeShipmentStatusTransition(tx, {
        shipmentId: id,
        previousStatus: shipment.status,
        nextStatus: payload.status,
        audience: [shipment.customerId, shipment.assignedTravelerId],
        actorId: requester.sub,
      });

      if (payload.status === ShipmentStatus.delivered && payload.imageUrls?.length) {
        await tx.shipmentImage.createMany({
          data: payload.imageUrls.map((imageUrl) => ({
            shipmentId: id,
            imageUrl,
            kind: 'delivery_proof',
          })),
        });
      }

      return nextTransition;
    });

    const shipmentCategoryText = `${shipment.packageCategory ?? ''} ${shipment.packageType ?? ''} ${shipment.description ?? ''}`.toLowerCase();
    const isMedicineShipment = shipmentCategoryText.includes('medicina');

    await dispatchShipmentStatusTransitionSideEffects({
      notificationsService: this.notificationsService,
      realtimeGateway: this.realtimeGateway,
      shipmentId: transition.shipmentId,
      previousStatus: transition.previousStatus,
      nextStatus: transition.nextStatus,
      audience: transition.audience,
      notificationAudience:
        payload.status === ShipmentStatus.picked_up || payload.status === ShipmentStatus.delivered
          ? [shipment.customerId]
          : transition.audience,
      title:
        payload.status === ShipmentStatus.picked_up
          ? 'Envío en ruta'
          : payload.status === ShipmentStatus.delivered
            ? 'Entrega confirmada'
            : undefined,
      body:
        payload.status === ShipmentStatus.picked_up
          ? `Tu paquete ${transition.shipmentId} ya está en ruta hacia su destino.`
          : payload.status === ShipmentStatus.delivered
            ? `¡Entregado! Tu envío ${transition.shipmentId} ha sido recibido con éxito.`
            : undefined,
      notificationType:
        payload.status === ShipmentStatus.picked_up
          ? 'shipment_in_route'
          : payload.status === ShipmentStatus.delivered
            ? 'shipment_delivered'
            : undefined,
      highPriority: isMedicineShipment,
    });

    if (payload.status === ShipmentStatus.delivered) {
      await this.commissionsService.createCommissionForDeliveredShipment(transition.updatedShipment);
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
