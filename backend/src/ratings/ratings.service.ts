import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ShipmentStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateRatingDto } from './dto/create-rating.dto';

type CreateRatingPayload = CreateRatingDto & { fromUserId: string };

@Injectable()
export class RatingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  getBlueprint() {
    return {
      flow: 'customer_to_traveler and traveler_to_customer',
    };
  }

  async findByUser(userId: string, requester: { sub: string; role: string }) {
    if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
      throw new ForbiddenException('No tienes permiso para ver estas calificaciones.');
    }

    return this.prisma.rating.findMany({
      where: { toUserId: userId },
      include: {
        fromUser: {
          select: {
            id: true,
            fullName: true,
            role: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(payload: CreateRatingPayload) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: payload.shipmentId },
      include: { assignedTraveler: true, customer: true },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    if (shipment.status !== ShipmentStatus.delivered) {
      throw new BadRequestException('Solo puedes calificar después de que el envío haya sido entregado.');
    }

    const fromUser = await this.prisma.user.findUnique({
      where: { id: payload.fromUserId },
    });

    if (!fromUser) {
      throw new NotFoundException('Usuario emisor no encontrado.');
    }

    let toUserId: string | null = null;

    if (payload.fromUserId == shipment.customerId) {
      toUserId = shipment.assignedTravelerId;
    } else if (payload.fromUserId == shipment.assignedTravelerId) {
      toUserId = shipment.customerId;
    }

    if (!toUserId) {
      throw new BadRequestException('No se pudo determinar a quién pertenece esta calificación.');
    }

    const existing = await this.prisma.rating.findFirst({
      where: {
        shipmentId: payload.shipmentId,
        fromUserId: payload.fromUserId,
        toUserId,
      },
    });

    if (existing) {
      throw new BadRequestException('Ya existe una calificación enviada para este envío.');
    }

    const rating = await this.prisma.rating.create({
      data: {
        shipmentId: payload.shipmentId,
        fromUserId: payload.fromUserId,
        toUserId,
        stars: payload.stars,
        comment: payload.comment,
      },
    });

    const aggregate = await this.prisma.rating.aggregate({
      where: { toUserId },
      _avg: { stars: true },
      _count: { stars: true },
    });

    const travelerProfile = await this.prisma.travelerProfile.findUnique({
      where: { userId: toUserId },
    });

    if (travelerProfile) {
      await this.prisma.travelerProfile.update({
        where: { userId: toUserId },
        data: {
          ratingAvg: aggregate._avg.stars ?? 0,
          ratingCount: aggregate._count.stars,
        },
      });
    }

    await this.notificationsService.sendPush(
      toUserId,
      'Nueva calificación',
      `Recibiste ${payload.stars} estrella(s) por el envío ${payload.shipmentId}.`,
      'rating',
      payload.shipmentId,
    );

    return rating;
  }
}
