import { OnGatewayConnection } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../database/prisma/prisma.service';
export declare class RealtimeGateway implements OnGatewayConnection {
    private readonly jwtService;
    private readonly prisma;
    private readonly logger;
    server: Server;
    constructor(jwtService: JwtService, prisma: PrismaService);
    handleConnection(client: Socket): Promise<void>;
    emitChatMessage(shipmentId: string, payload: unknown): void;
    emitTrackingUpdated(shipmentId: string, payload: unknown): void;
    emitOfferUpdated(shipmentId: string, payload: unknown): void;
    emitShipmentStatusChanged(shipmentId: string, payload: unknown): void;
    emitNotificationUpdated(userId: string, payload: unknown): void;
    joinChat(body: {
        shipmentId?: string;
    }, client: Socket): Promise<{
        ok: boolean;
        room: string;
    }>;
    joinTracking(body: {
        shipmentId?: string;
    }, client: Socket): Promise<{
        ok: boolean;
        room: string;
    }>;
    joinOffers(body: {
        shipmentId?: string;
    }, client: Socket): Promise<{
        ok: boolean;
        room: string;
    }>;
    private authenticate;
    private ensureParticipantAccess;
    private ensureOfferAccess;
}
