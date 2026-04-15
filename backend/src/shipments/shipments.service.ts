import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ShipmentStatus } from '@prisma/client';
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

  async create(payload: CreateShipmentDto) {
    const direction = this.geoService.resolveDirection(
      payload.originCountryCode,
      payload.destinationCountryCode,
    );

    if (!direction) {
      throw new BadRequestException('Solo se permiten rutas Guatemala ↔ USA.');
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
        deliveryLat: payload.deliveryLat,
        deliveryLng: payload.deliveryLng,
        insuranceEnabled: payload.insuranceEnabled,
      },
    });
  }

  async findAll() {
    return this.prisma.shipment.findMany({
      include: {
        offers: true,
        commission: true,
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
      },
    });

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

    return this.findOne(id);
  }
}
