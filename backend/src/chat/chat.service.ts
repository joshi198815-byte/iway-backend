import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { AntiFraudService } from '../anti-fraud/anti-fraud.service';
import { SendMessageDto } from './dto/send-message.dto';

type SendMessagePayload = SendMessageDto & { senderId: string };
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly antiFraudService: AntiFraudService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

  async findMessages(chatId: string, userId: string) {
    const chat = await this.prisma.chat.findUnique({
      where: { id: chatId },
      include: {
        shipment: true,
        messages: {
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!chat) {
      throw new NotFoundException('Chat no encontrado.');
    }

    const canAccess =
      chat.shipment.customerId === userId || chat.shipment.assignedTravelerId === userId;

    if (!canAccess) {
      throw new ForbiddenException('No tienes acceso a este chat.');
    }

    return chat.messages;
  }

  async getOrCreateByShipment(shipmentId: string, userId: string) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: shipmentId },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    const canAccess = shipment.customerId === userId || shipment.assignedTravelerId === userId;

    if (!canAccess) {
      throw new ForbiddenException('No tienes acceso a este chat.');
    }

    return this.prisma.chat.upsert({
      where: { shipmentId },
      update: {},
      create: { shipmentId },
    });
  }

  async sendMessage(payload: SendMessagePayload) {
    const chat = await this.prisma.chat.findUnique({
      where: { id: payload.chatId },
      include: { shipment: true },
    });

    if (!chat) {
      throw new NotFoundException('Chat no encontrado.');
    }

    const canAccess =
      chat.shipment.customerId === payload.senderId ||
      chat.shipment.assignedTravelerId === payload.senderId;

    if (!canAccess) {
      throw new ForbiddenException('No tienes acceso a este chat.');
    }

    const analysis = this.antiFraudService.analyzeMessage(payload.body);

    const message = await this.prisma.message.create({
      data: {
        chatId: payload.chatId,
        senderId: payload.senderId,
        body: analysis.sanitizedBody,
        riskStatus: analysis.riskStatus,
        riskFlags: analysis.flags,
        containsPhone: analysis.containsPhone,
        containsEmail: analysis.containsEmail,
        containsExternalLink: analysis.containsExternalLink,
      },
    });

    await this.antiFraudService.createFlags({
      userId: payload.senderId,
      shipmentId: chat.shipmentId,
      messageId: message.id,
      flags: analysis.flags,
    });

    this.realtimeGateway.emitChatMessage(chat.shipmentId, {
      shipmentId: chat.shipmentId,
      message,
    });

    return {
      message,
      moderation: {
        riskStatus: analysis.riskStatus,
        flags: analysis.flags,
        directContactBlocked:
          analysis.sanitizedBody ===
          '[mensaje bloqueado por posible intento de sacar la conversación fuera de iway]',
      },
    };
  }
}
