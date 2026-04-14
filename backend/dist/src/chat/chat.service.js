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
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
const anti_fraud_service_1 = require("../anti-fraud/anti-fraud.service");
const realtime_gateway_1 = require("../realtime/realtime.gateway");
let ChatService = class ChatService {
    constructor(prisma, antiFraudService, realtimeGateway) {
        this.prisma = prisma;
        this.antiFraudService = antiFraudService;
        this.realtimeGateway = realtimeGateway;
    }
    async findMessages(chatId, userId) {
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
            throw new common_1.NotFoundException('Chat no encontrado.');
        }
        const canAccess = chat.shipment.customerId === userId || chat.shipment.assignedTravelerId === userId;
        if (!canAccess) {
            throw new common_1.ForbiddenException('No tienes acceso a este chat.');
        }
        return chat.messages;
    }
    async getOrCreateByShipment(shipmentId, userId) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: shipmentId },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        const canAccess = shipment.customerId === userId || shipment.assignedTravelerId === userId;
        if (!canAccess) {
            throw new common_1.ForbiddenException('No tienes acceso a este chat.');
        }
        return this.prisma.chat.upsert({
            where: { shipmentId },
            update: {},
            create: { shipmentId },
        });
    }
    async sendMessage(payload) {
        const chat = await this.prisma.chat.findUnique({
            where: { id: payload.chatId },
            include: { shipment: true },
        });
        if (!chat) {
            throw new common_1.NotFoundException('Chat no encontrado.');
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
                directContactBlocked: analysis.sanitizedBody ===
                    '[mensaje bloqueado por posible intento de sacar la conversación fuera de iway]',
            },
        };
    }
};
exports.ChatService = ChatService;
exports.ChatService = ChatService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        anti_fraud_service_1.AntiFraudService,
        realtime_gateway_1.RealtimeGateway])
], ChatService);
//# sourceMappingURL=chat.service.js.map