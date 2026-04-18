import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ShipmentStatus, TravelerStatus, type ShipmentDirection } from '@prisma/client';
import { CommissionsService } from '../commissions/commissions.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { GeoService } from '../geo/geo.service';
import { CreateShipmentDto } from './dto/create-shipment.dto';
import { UpdateShipmentStatusDto } from './dto/update-shipment-status.dto';

@Injectable()
export class ShipmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly geoService: GeoService,
    private readonly commissionsService: CommissionsService,
  ) {}

  private normalizeDecimal(value: unknown) {
    const parsed = Number(value ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
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
      select: { id: true, role: true, phoneVerified: true },
    });

    if (!customer || customer.role !== 'customer') {
      throw new BadRequestException('No se pudo identificar al cliente autenticado.');
    }

    if (!customer.phoneVerified) {
      throw new ForbiddenException('Debes validar tu número de teléfono antes de crear un envío.');
    }

    return this.prisma.shipment.create({
      data: {
        customerId: payload.customerId,
        status: ShipmentStatus.published,
        direction,
        originCountryCode: payload.originCountryCode.toUpperCase(),
        destinationCountryCode: payload.destinationCountryCode.toUpperCase(),
        packageType: payload.packageType,
        packageCategory: payload.packageCategory,
        description: payload.description,
        declaredValue: payload.declaredValue,
        weightLb: payload.weightLb,
        receiverName: payload.receiverName,
        receiverPhone: payload.receiverPhone,
        receiverAddress: payload.receiverAddress,
        pickupLat: payload.pickupLat,
        pickupLng: payload.pickupLng,
        deliveryLat: payload.deliveryLat,
        deliveryLng: payload.deliveryLng,
        insuranceEnabled: payload.insuranceEnabled,
      },
    });
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

    const activeDirections = [...new Set(travelerProfile.routes.map((route) => route.direction))] as ShipmentDirection[];

    const shipments = await this.prisma.shipment.findMany({
      where: {
        status: { in: [ShipmentStatus.published, ShipmentStatus.offered] },
        assignedTravelerId: null,
        customerId: { not: travelerId },
        ...(activeDirections.length > 0 ? { direction: { in: activeDirections } } : {}),
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

        const insights = [
          activeDirections.includes(shipment.direction) ? 'Coincide con tu ruta activa' : 'Revisa si esta ruta encaja con tu operación',
          offerCount === 0 ? 'Sin competencia todavía' : `${offerCount} oferta${offerCount === 1 ? '' : 's'} activa${offerCount === 1 ? '' : 's'}`,
          minOfferPrice > 0 ? `Oferta más baja actual: $${minOfferPrice.toFixed(2)}` : 'Aún no hay ofertas registradas',
          shipment.insuranceEnabled ? 'Incluye seguro declarado' : 'Sin seguro adicional',
        ];

        return {
          ...shipment,
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
    const shipment = await this.prisma.shipment.findUnique({ where: { id } });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    const isPrivileged = ['admin', 'support'].includes(requester.role);
    const isAssignedTraveler = shipment.assignedTravelerId === requester.sub;

    if (!isPrivileged) {
      const travelerAllowedStatuses: ShipmentStatus[] = [
        ShipmentStatus.picked_up,
        ShipmentStatus.in_transit,
        ShipmentStatus.in_delivery,
        ShipmentStatus.delivered,
      ];

      if (!isAssignedTraveler || !travelerAllowedStatuses.includes(payload.status)) {
        throw new ForbiddenException('No tienes permiso para actualizar este estado.');
      }
    }

    const updated = await this.prisma.shipment.update({
      where: { id },
      data: {
        status: payload.status,
      },
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

    await this.prisma.shipmentEvent.create({
      data: {
        shipmentId: id,
        eventType: `status_${payload.status}`,
        eventPayload: {
          previousStatus: shipment.status,
          nextStatus: payload.status,
        },
      },
    });

    if (payload.status === ShipmentStatus.delivered) {
      await this.commissionsService.createCommissionForDeliveredShipment(updated);
    }

    return this.prisma.shipment.findUnique({
      where: { id },
      include: {
        offers: true,
        events: true,
        commission: true,
      },
    });
  }
}
