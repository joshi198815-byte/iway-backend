import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ShipmentStatus } from '@prisma/client';
import { CommissionsService } from '../commissions/commissions.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { GeoService } from '../geo/geo.service';
import { CreateShipmentDto } from './dto/create-shipment.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';
import { UpdateShipmentStatusDto } from './dto/update-shipment-status.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class ShipmentsService {
  private normalizeDecimal(value: unknown) {
    const parsed = Number(value ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private decorateOpportunity(shipment: any) {
    const offerCount = shipment.offers?.length ?? 0;
    const weight = this.normalizeDecimal(shipment.weightLb);
    const declaredValue = this.normalizeDecimal(shipment.declaredValue);
    const antiFraudScore = Number(shipment.antiFraudScore ?? 0);
    const hoursOpen = Math.max(1, (Date.now() - new Date(shipment.createdAt).getTime()) / 3600000);

    let marketScore = 38;
    if (shipment.status === ShipmentStatus.published) marketScore += 12;
    else marketScore += 6;
    if (offerCount === 0) marketScore += 18;
    else if (offerCount <= 2) marketScore += 10;
    else if (offerCount >= 5) marketScore -= 8;
    if (weight > 0 && weight <= 15) marketScore += 16;
    else if (weight <= 40) marketScore += 10;
    else marketScore += 4;
    if (declaredValue >= 50 && declaredValue <= 500) marketScore += 12;
    else marketScore += 6;
    if (shipment.insuranceEnabled) marketScore += 6;
    if (hoursOpen <= 12) marketScore += 10;
    else if (hoursOpen <= 36) marketScore += 4;
    if (antiFraudScore > 70) marketScore -= 10;
    else if (antiFraudScore <= 25) marketScore += 4;
    marketScore = Math.max(1, Math.min(100, Math.round(marketScore)));

    const marketInsights = [
      offerCount == 0 ? 'Sin competencia todavía' : `${offerCount} oferta${offerCount == 1 ? '' : 's'} activa${offerCount == 1 ? '' : 's'}`,
      weight > 0 && weight <= 15 ? 'Peso ligero, cierre más ágil' : weight > 0 ? 'Carga viable para ruta regular' : 'Peso pendiente de validar',
      hoursOpen <= 12 ? 'Publicado recientemente' : 'Oportunidad abierta y visible',
      antiFraudScore > 70 ? 'Requiere revisión operativa extra' : 'Riesgo operativo normal',
    ];

    return {
      ...shipment,
      offerCount,
      marketplaceScore: marketScore,
      marketplaceTier: marketScore >= 80 ? 'prime' : marketScore >= 65 ? 'strong' : 'watch',
      marketplaceInsights: marketInsights,
    };
  }

  constructor(
    private readonly prisma: PrismaService,
    private readonly geoService: GeoService,
    private readonly commissionsService: CommissionsService,
    private readonly notificationsService: NotificationsService,
    private readonly storageService: StorageService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

  async create(payload: CreateShipmentDto) {
    const direction = this.geoService.resolveDirection(
      payload.originCountryCode,
      payload.destinationCountryCode,
    );

    if (!direction) {
      throw new BadRequestException('Solo se permiten rutas Guatemala ↔ USA.');
    }

    const createdShipment = await this.prisma.shipment.create({
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
        images: payload.imageUrls && payload.imageUrls.length > 0
            ? {
                create: payload.imageUrls.map((imageUrl) => ({
                  imageUrl,
                  kind: 'package_reference',
                })),
              }
            : undefined,
      },
      include: {
        images: true,
      },
    });

    const matchingTravelers = await this.prisma.travelerProfile.findMany({
      where: {
        status: {
          in: ['pending', 'verified'],
        },
        routes: {
          some: {
            direction,
            active: true,
          },
        },
      },
      select: {
        userId: true,
      },
    });

    await this.notificationsService.sendPushMany(
      matchingTravelers.map((traveler) => traveler.userId),
      'Nuevo envío disponible',
      `Hay un nuevo envío ${createdShipment.id} en la ruta ${payload.originCountryCode.toUpperCase()} → ${payload.destinationCountryCode.toUpperCase()}.`,
      'shipment_available',
      createdShipment.id,
    );

    if (payload.imageUrls && payload.imageUrls.length > 0) {
      await this.storageService.attachFilesToEntity({
        ownerId: payload.customerId,
        urls: payload.imageUrls,
        linkedEntityType: 'shipment',
        linkedEntityId: createdShipment.id,
        purpose: 'shipment_reference',
      });
    }

    return createdShipment;
  }

  async findAvailableForTraveler(travelerId: string, role: string) {
    if (!['traveler', 'admin', 'support'].includes(role)) {
      throw new ForbiddenException('Solo viajeros o personal interno pueden ver oportunidades.');
    }

    if (['admin', 'support'].includes(role)) {
      const shipments = await this.prisma.shipment.findMany({
        where: {
          status: { in: [ShipmentStatus.published, ShipmentStatus.offered] },
          assignedTravelerId: null,
        },
        include: { images: true, offers: true },
        orderBy: { createdAt: 'desc' },
      });

      return shipments.map((shipment) => this.decorateOpportunity(shipment)).sort((a, b) => b.marketplaceScore - a.marketplaceScore);
    }

    const traveler = await this.prisma.travelerProfile.findUnique({
      where: { userId: travelerId },
      include: { routes: true },
    });

    if (!traveler) {
      throw new NotFoundException('Perfil de viajero no encontrado.');
    }

    const allowedDirections = traveler.routes.filter((route) => route.active).map((route) => route.direction);

    const shipments = await this.prisma.shipment.findMany({
      where: {
        status: { in: [ShipmentStatus.published, ShipmentStatus.offered] },
        assignedTravelerId: null,
        direction: { in: allowedDirections },
        offers: {
          none: {
            travelerId,
          },
        },
      },
      include: { images: true, offers: true },
      orderBy: { createdAt: 'desc' },
    });

    return shipments.map((shipment) => this.decorateOpportunity(shipment)).sort((a, b) => b.marketplaceScore - a.marketplaceScore);
  }

  async findAll() {
    return this.prisma.shipment.findMany({
      include: {
        offers: true,
        commission: true,
        images: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id },
      include: {
        offers: true,
        events: true,
        commission: true,
        images: true,
      },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    return shipment;
  }

  async updateStatus(id: string, payload: UpdateShipmentStatusDto) {
    const shipment = await this.findOne(id);

    const updated = await this.prisma.shipment.update({
      where: { id },
      data: {
        status: payload.status,
        images: payload.status === ShipmentStatus.delivered && payload.imageUrls?.length
            ? {
                create: payload.imageUrls.map((imageUrl) => ({
                  imageUrl,
                  kind: 'delivery_proof',
                })),
              }
            : undefined,
      },
      include: {
        images: true,
      },
    });

    await this.prisma.shipmentEvent.create({
      data: {
        shipmentId: id,
        eventType: `status_${payload.status}`,
        eventPayload: {
          previousStatus: shipment.status,
          nextStatus: payload.status,
          deliveryProofCount:
            payload.status === ShipmentStatus.delivered ? payload.imageUrls?.length ?? 0 : 0,
        },
      },
    });

    this.realtimeGateway.emitShipmentStatusChanged(id, {
      shipmentId: id,
      previousStatus: shipment.status,
      nextStatus: payload.status,
    });

    if (payload.status === ShipmentStatus.delivered) {
      await this.commissionsService.createCommissionForDeliveredShipment(updated);

      if (payload.imageUrls && payload.imageUrls.length > 0 && shipment.assignedTravelerId) {
        await this.storageService.attachFilesToEntity({
          ownerId: shipment.assignedTravelerId,
          urls: payload.imageUrls,
          linkedEntityType: 'shipment',
          linkedEntityId: shipment.id,
          purpose: 'delivery_proof',
        });
      }

      await this.notificationsService.sendPush(
        shipment.customerId,
        'Envío entregado',
        `Tu envío ${shipment.id} fue marcado como entregado${(payload.imageUrls?.length ?? 0) > 0 ? ' con evidencia visual' : ''}.`,
        'shipment_delivered',
        shipment.id,
      );

      if (shipment.assignedTravelerId) {
        await this.notificationsService.sendPush(
          shipment.assignedTravelerId,
          'Entrega registrada',
          `El envío ${shipment.id} quedó cerrado como entregado.`,
          'delivery_closed',
          shipment.id,
        );
      }
    }

    return this.findOne(id);
  }
}
