import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { OfferStatus, ShipmentStatus, TravelerStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AcceptOfferDto } from './dto/accept-offer.dto';
import { CreateOfferDto } from './dto/create-offer.dto';

type CreateOfferPayload = CreateOfferDto & { travelerId: string };
type AcceptOfferPayload = AcceptOfferDto & { acceptedByCustomerId: string };
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { runtimeObservability } from '../common/observability/runtime-observability';

@Injectable()
export class OffersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

  private normalizeDecimal(value: unknown) {
    const parsed = Number(value ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private scoreOffer(params: {
    price: number;
    minPrice: number;
    verificationScore: number;
    ratingAvg: number;
    deliveredCount: number;
    acceptanceRate: number;
    travelerStatus: string;
    currentDebt: number;
  }) {
    let score = 35;

    if (params.minPrice > 0) {
      const competitiveness = Math.max(0.35, Math.min(1.1, params.minPrice / Math.max(params.price, 1)));
      score += competitiveness * 22;
    }

    score += Math.min(18, params.verificationScore * 0.18);
    score += Math.min(14, params.ratingAvg * 3.2);
    score += Math.min(12, params.deliveredCount * 1.5);
    score += Math.min(10, params.acceptanceRate * 10);

    if (params.travelerStatus === 'verified') score += 8;
    if (params.travelerStatus === 'pending') score += 2;
    if (params.currentDebt > 0) score -= Math.min(8, params.currentDebt / 20);

    return Math.max(1, Math.min(100, Math.round(score)));
  }

  async create(payload: CreateOfferPayload) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: payload.shipmentId },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId: payload.travelerId },
    });

    if (!traveler) {
      throw new BadRequestException('El viajero no existe o no está configurado.');
    }

    if (traveler.status === TravelerStatus.blocked_for_debt) {
      throw new BadRequestException('El viajero está bloqueado por deuda.');
    }

    if (traveler.status === TravelerStatus.blocked || traveler.status === TravelerStatus.rejected) {
      throw new BadRequestException('Tu perfil no puede ofertar hasta completar la revisión KYC.');
    }

    if (traveler.status !== TravelerStatus.verified && (traveler.verificationScore ?? 0) < 65) {
      throw new BadRequestException('Tu perfil necesita una validación KYC más sólida antes de ofertar.');
    }

    const offer = await this.prisma.offer.create({
      data: {
        shipmentId: payload.shipmentId,
        travelerId: payload.travelerId,
        price: payload.price,
      },
    });

    await this.prisma.shipment.update({
      where: { id: payload.shipmentId },
      data: {
        status: ShipmentStatus.offered,
      },
    });

    await this.notificationsService.sendPush(
      shipment.customerId,
      'Nueva oferta recibida',
      `Un viajero envió una oferta para tu envío ${payload.shipmentId}.`,
      'offer',
      payload.shipmentId,
    );

    this.realtimeGateway.emitOfferUpdated(payload.shipmentId, {
      shipmentId: payload.shipmentId,
      action: 'created',
      offer,
    });

    runtimeObservability.recordBusinessEvent({
      type: 'offer_created',
      entityId: offer.id,
      actorId: payload.travelerId,
      shipmentId: payload.shipmentId,
      metadata: { price: Number(offer.price) },
    });

    return offer;
  }

  async findByShipment(shipmentId: string, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: shipmentId },
      select: { customerId: true, assignedTravelerId: true, status: true },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    const requesterOffer = requester.role === 'traveler'
      ? await this.prisma.offer.findFirst({
          where: { shipmentId, travelerId: requester.sub },
          select: { id: true, status: true },
        })
      : null;

    const canAccess =
      ['admin', 'support'].includes(requester.role) ||
      shipment.customerId === requester.sub ||
      shipment.assignedTravelerId === requester.sub ||
      requester.role === 'traveler' ||
      requesterOffer != null;

    if (!canAccess) {
      throw new ForbiddenException('No tienes acceso a las ofertas de este envío.');
    }

    const offers = await this.prisma.offer.findMany({
      where: { shipmentId },
      include: {
        traveler: {
          include: {
            travelerProfile: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    if (offers.length === 0) {
      return offers;
    }

    const visibleOffers = shipment.assignedTravelerId != null && !['admin', 'support'].includes(requester.role)
      ? offers.filter((offer) => offer.status === OfferStatus.accepted)
      : offers;

    const travelerIds = [...new Set(visibleOffers.map((offer) => offer.travelerId))];
    const [acceptedOffers, deliveredShipments] = await Promise.all([
      this.prisma.offer.findMany({
        where: { travelerId: { in: travelerIds }, status: OfferStatus.accepted },
        select: { travelerId: true },
      }),
      this.prisma.shipment.findMany({
        where: { assignedTravelerId: { in: travelerIds }, status: ShipmentStatus.delivered },
        select: { assignedTravelerId: true },
      }),
    ]);

    const acceptedByTraveler = acceptedOffers.reduce<Record<string, number>>((acc, item) => {
      acc[item.travelerId] = (acc[item.travelerId] ?? 0) + 1;
      return acc;
    }, {});

    const deliveredByTraveler = deliveredShipments.reduce<Record<string, number>>((acc, item) => {
      if (!item.assignedTravelerId) return acc;
      acc[item.assignedTravelerId] = (acc[item.assignedTravelerId] ?? 0) + 1;
      return acc;
    }, {});

    const minPrice = Math.min(...visibleOffers.map((offer) => this.normalizeDecimal(offer.price)));

    return visibleOffers
      .map((offer) => {
        const profile = offer.traveler.travelerProfile;
        const acceptedCount = acceptedByTraveler[offer.travelerId] ?? 0;
        const deliveredCount = deliveredByTraveler[offer.travelerId] ?? 0;
        const acceptanceRate = acceptedCount > 0 ? deliveredCount / acceptedCount : 0;
        const score = this.scoreOffer({
          price: this.normalizeDecimal(offer.price),
          minPrice,
          verificationScore: profile?.verificationScore ?? 0,
          ratingAvg: this.normalizeDecimal(profile?.ratingAvg),
          deliveredCount,
          acceptanceRate,
          travelerStatus: profile?.status ?? 'pending',
          currentDebt: this.normalizeDecimal(profile?.currentDebt),
        });

        const insights = [
          profile?.status === 'verified' ? 'Perfil verificado' : 'Perfil en revisión',
          deliveredCount > 0 ? `${deliveredCount} entregas cerradas` : 'Sin entregas cerradas aún',
          acceptanceRate >= 0.8 ? 'Muy buen cumplimiento' : acceptanceRate >= 0.5 ? 'Cumplimiento estable' : 'Cumplimiento por construir',
          this.normalizeDecimal(offer.price) === minPrice ? 'Precio más competitivo' : 'Precio comparado con otras ofertas',
        ];

        return {
          ...offer,
          travelerName: offer.traveler.fullName,
          travelerStatus: profile?.status ?? 'pending',
          travelerVerificationScore: profile?.verificationScore ?? 0,
          travelerRatingAvg: this.normalizeDecimal(profile?.ratingAvg),
          travelerRatingCount: profile?.ratingCount ?? 0,
          deliveredCount,
          acceptanceRate: Number(acceptanceRate.toFixed(2)),
          marketplaceScore: score,
          marketplaceTier: score >= 80 ? 'prime' : score >= 65 ? 'strong' : 'watch',
          marketplaceInsights: insights,
        };
      })
      .sort((a, b) => Number(b.marketplaceScore) - Number(a.marketplaceScore));
  }

  async acceptOffer(offerId: string, payload: AcceptOfferPayload) {
    const offer = await this.prisma.offer.findUnique({
      where: { id: offerId },
      include: { shipment: true },
    });

    if (!offer) {
      throw new NotFoundException('Oferta no encontrada.');
    }

    if (offer.shipment.customerId !== payload.acceptedByCustomerId) {
      throw new ForbiddenException('Solo el cliente dueño del envío puede aceptar esta oferta.');
    }

    if (offer.status !== OfferStatus.pending) {
      throw new BadRequestException('Esta oferta ya no se puede aceptar.');
    }

    if (offer.shipment.assignedTravelerId) {
      throw new BadRequestException('Este envío ya fue asignado a un viajero.');
    }

    await this.prisma.$transaction([
      this.prisma.offer.updateMany({
        where: {
          shipmentId: offer.shipmentId,
          id: { not: offerId },
        },
        data: {
          status: OfferStatus.rejected,
        },
      }),
      this.prisma.offer.update({
        where: { id: offerId },
        data: {
          status: OfferStatus.accepted,
        },
      }),
      this.prisma.shipment.update({
        where: { id: offer.shipmentId },
        data: {
          status: ShipmentStatus.assigned,
          assignedTravelerId: offer.travelerId,
        },
      }),
    ]);

    await this.prisma.chat.upsert({
      where: { shipmentId: offer.shipmentId },
      update: {},
      create: { shipmentId: offer.shipmentId },
    });

    await this.notificationsService.sendPush(
      offer.travelerId,
      'Oferta aceptada',
      `Tu oferta para el envío ${offer.shipmentId} fue aceptada.`,
      'offer_accepted',
      offer.shipmentId,
    );

    await this.notificationsService.sendPush(
      offer.shipment.customerId,
      'Envío asignado',
      `Tu envío ${offer.shipmentId} ya fue asignado a un viajero.`,
      'shipment_assigned',
      offer.shipmentId,
    );

    const acceptedOffer = await this.prisma.offer.findUnique({
      where: { id: offerId },
      include: { shipment: true },
    });

    this.realtimeGateway.emitOfferUpdated(offer.shipmentId, {
      shipmentId: offer.shipmentId,
      action: 'accepted',
      offerId,
      travelerId: offer.travelerId,
    });
    this.realtimeGateway.emitShipmentStatusChanged(offer.shipmentId, {
      shipmentId: offer.shipmentId,
      previousStatus: offer.shipment.status,
      nextStatus: 'assigned',
    });

    runtimeObservability.recordBusinessEvent({
      type: 'offer_accepted',
      entityId: offerId,
      actorId: payload.acceptedByCustomerId,
      shipmentId: offer.shipmentId,
      metadata: { travelerId: offer.travelerId },
    });

    return acceptedOffer;
  }
}
