import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { ForbiddenException, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../database/prisma/prisma.service';

type AuthUser = { sub: string; role: string };

@WebSocketGateway({
  namespace: '/realtime',
  cors: { origin: '*' },
})
export class RealtimeGateway implements OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      client.data.user = await this.authenticate(client);
      await client.join(`user:${(client.data.user as AuthUser).sub}`);
    } catch (error) {
      this.logger.warn(`socket rejected: ${(error as Error).message}`);
      client.disconnect(true);
    }
  }

  emitChatMessage(shipmentId: string, payload: unknown) {
    this.server.to(`chat:${shipmentId}`).emit('chat_message', payload);
  }

  emitTrackingUpdated(shipmentId: string, payload: unknown) {
    this.server.to(`tracking:${shipmentId}`).emit('tracking_updated', payload);
  }

  emitOfferUpdated(shipmentId: string, payload: unknown) {
    this.server.to(`offers:${shipmentId}`).emit('offer_updated', payload);
  }

  emitShipmentStatusChanged(shipmentId: string, payload: unknown) {
    this.server.to(`tracking:${shipmentId}`).emit('shipment_status_changed', payload);
    this.server.to(`offers:${shipmentId}`).emit('shipment_status_changed', payload);
  }

  emitNotificationUpdated(userId: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit('notification_updated', payload);
  }

  @SubscribeMessage('join_chat')
  async joinChat(
    @MessageBody() body: { shipmentId?: string },
    @ConnectedSocket() client: Socket,
  ) {
    const shipmentId = body?.shipmentId?.trim();
    if (!shipmentId) {
      throw new ForbiddenException('shipmentId requerido');
    }

    await this.ensureParticipantAccess(shipmentId, client.data.user as AuthUser);
    await client.join(`chat:${shipmentId}`);
    return { ok: true, room: `chat:${shipmentId}` };
  }

  @SubscribeMessage('join_tracking')
  async joinTracking(
    @MessageBody() body: { shipmentId?: string },
    @ConnectedSocket() client: Socket,
  ) {
    const shipmentId = body?.shipmentId?.trim();
    if (!shipmentId) {
      throw new ForbiddenException('shipmentId requerido');
    }

    await this.ensureParticipantAccess(shipmentId, client.data.user as AuthUser);
    await client.join(`tracking:${shipmentId}`);
    return { ok: true, room: `tracking:${shipmentId}` };
  }

  @SubscribeMessage('join_offers')
  async joinOffers(
    @MessageBody() body: { shipmentId?: string },
    @ConnectedSocket() client: Socket,
  ) {
    const shipmentId = body?.shipmentId?.trim();
    if (!shipmentId) {
      throw new ForbiddenException('shipmentId requerido');
    }

    await this.ensureOfferAccess(shipmentId, client.data.user as AuthUser);
    await client.join(`offers:${shipmentId}`);
    return { ok: true, room: `offers:${shipmentId}` };
  }

  private async authenticate(client: Socket) {
    const rawToken =
      (client.handshake.auth?.token as string | undefined) ??
      (client.handshake.headers.authorization as string | undefined);

    if (!rawToken) {
      throw new UnauthorizedException('missing token');
    }

    const token = rawToken.replace(/^Bearer\s+/i, '').trim();
    if (!token) {
      throw new UnauthorizedException('invalid token');
    }

    return this.jwtService.verify<AuthUser>(token, {
      secret: process.env.JWT_SECRET ?? 'change-me',
    });
  }

  private async ensureParticipantAccess(shipmentId: string, user: AuthUser) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: shipmentId },
      select: { customerId: true, assignedTravelerId: true },
    });

    if (!shipment) {
      throw new ForbiddenException('Envío no encontrado');
    }

    const privileged = ['admin', 'support'].includes(user.role);
    const participant =
      shipment.customerId === user.sub || shipment.assignedTravelerId === user.sub;

    if (!privileged && !participant) {
      throw new ForbiddenException('Sin acceso a este room');
    }
  }

  private async ensureOfferAccess(shipmentId: string, user: AuthUser) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: shipmentId },
      select: { customerId: true, assignedTravelerId: true },
    });

    if (!shipment) {
      throw new ForbiddenException('Envío no encontrado');
    }

    if (['admin', 'support'].includes(user.role)) {
      return;
    }

    if (shipment.customerId === user.sub || shipment.assignedTravelerId === user.sub) {
      return;
    }

    throw new ForbiddenException('Sin acceso a este room');
  }
}
