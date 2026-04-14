"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var RealtimeGateway_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RealtimeGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const socket_io_1 = require("socket.io");
const prisma_service_1 = require("../database/prisma/prisma.service");
let RealtimeGateway = RealtimeGateway_1 = class RealtimeGateway {
    constructor(jwtService, prisma) {
        this.jwtService = jwtService;
        this.prisma = prisma;
        this.logger = new common_1.Logger(RealtimeGateway_1.name);
    }
    async handleConnection(client) {
        try {
            client.data.user = await this.authenticate(client);
            await client.join(`user:${client.data.user.sub}`);
        }
        catch (error) {
            this.logger.warn(`socket rejected: ${error.message}`);
            client.disconnect(true);
        }
    }
    emitChatMessage(shipmentId, payload) {
        this.server.to(`chat:${shipmentId}`).emit('chat_message', payload);
    }
    emitTrackingUpdated(shipmentId, payload) {
        this.server.to(`tracking:${shipmentId}`).emit('tracking_updated', payload);
    }
    emitOfferUpdated(shipmentId, payload) {
        this.server.to(`offers:${shipmentId}`).emit('offer_updated', payload);
    }
    emitShipmentStatusChanged(shipmentId, payload) {
        this.server.to(`tracking:${shipmentId}`).emit('shipment_status_changed', payload);
        this.server.to(`offers:${shipmentId}`).emit('shipment_status_changed', payload);
    }
    emitNotificationUpdated(userId, payload) {
        this.server.to(`user:${userId}`).emit('notification_updated', payload);
    }
    async joinChat(body, client) {
        const shipmentId = body?.shipmentId?.trim();
        if (!shipmentId) {
            throw new common_1.ForbiddenException('shipmentId requerido');
        }
        await this.ensureParticipantAccess(shipmentId, client.data.user);
        await client.join(`chat:${shipmentId}`);
        return { ok: true, room: `chat:${shipmentId}` };
    }
    async joinTracking(body, client) {
        const shipmentId = body?.shipmentId?.trim();
        if (!shipmentId) {
            throw new common_1.ForbiddenException('shipmentId requerido');
        }
        await this.ensureParticipantAccess(shipmentId, client.data.user);
        await client.join(`tracking:${shipmentId}`);
        return { ok: true, room: `tracking:${shipmentId}` };
    }
    async joinOffers(body, client) {
        const shipmentId = body?.shipmentId?.trim();
        if (!shipmentId) {
            throw new common_1.ForbiddenException('shipmentId requerido');
        }
        await this.ensureOfferAccess(shipmentId, client.data.user);
        await client.join(`offers:${shipmentId}`);
        return { ok: true, room: `offers:${shipmentId}` };
    }
    async authenticate(client) {
        const rawToken = client.handshake.auth?.token ??
            client.handshake.headers.authorization;
        if (!rawToken) {
            throw new common_1.UnauthorizedException('missing token');
        }
        const token = rawToken.replace(/^Bearer\s+/i, '').trim();
        if (!token) {
            throw new common_1.UnauthorizedException('invalid token');
        }
        return this.jwtService.verify(token, {
            secret: process.env.JWT_SECRET ?? 'change-me',
        });
    }
    async ensureParticipantAccess(shipmentId, user) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: shipmentId },
            select: { customerId: true, assignedTravelerId: true },
        });
        if (!shipment) {
            throw new common_1.ForbiddenException('Envío no encontrado');
        }
        const privileged = ['admin', 'support'].includes(user.role);
        const participant = shipment.customerId === user.sub || shipment.assignedTravelerId === user.sub;
        if (!privileged && !participant) {
            throw new common_1.ForbiddenException('Sin acceso a este room');
        }
    }
    async ensureOfferAccess(shipmentId, user) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: shipmentId },
            select: { customerId: true, assignedTravelerId: true },
        });
        if (!shipment) {
            throw new common_1.ForbiddenException('Envío no encontrado');
        }
        if (['admin', 'support'].includes(user.role)) {
            return;
        }
        if (shipment.customerId === user.sub || shipment.assignedTravelerId === user.sub) {
            return;
        }
        if (user.role === 'traveler') {
            return;
        }
        throw new common_1.ForbiddenException('Sin acceso a este room');
    }
};
exports.RealtimeGateway = RealtimeGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], RealtimeGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('join_chat'),
    __param(0, (0, websockets_1.MessageBody)()),
    __param(1, (0, websockets_1.ConnectedSocket)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, socket_io_1.Socket]),
    __metadata("design:returntype", Promise)
], RealtimeGateway.prototype, "joinChat", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('join_tracking'),
    __param(0, (0, websockets_1.MessageBody)()),
    __param(1, (0, websockets_1.ConnectedSocket)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, socket_io_1.Socket]),
    __metadata("design:returntype", Promise)
], RealtimeGateway.prototype, "joinTracking", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('join_offers'),
    __param(0, (0, websockets_1.MessageBody)()),
    __param(1, (0, websockets_1.ConnectedSocket)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, socket_io_1.Socket]),
    __metadata("design:returntype", Promise)
], RealtimeGateway.prototype, "joinOffers", null);
exports.RealtimeGateway = RealtimeGateway = RealtimeGateway_1 = __decorate([
    (0, websockets_1.WebSocketGateway)({
        namespace: '/realtime',
        cors: { origin: '*' },
    }),
    __metadata("design:paramtypes", [jwt_1.JwtService,
        prisma_service_1.PrismaService])
], RealtimeGateway);
//# sourceMappingURL=realtime.gateway.js.map