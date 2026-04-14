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
exports.RatingsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
const notifications_service_1 = require("../notifications/notifications.service");
let RatingsService = class RatingsService {
    constructor(prisma, notificationsService) {
        this.prisma = prisma;
        this.notificationsService = notificationsService;
    }
    getBlueprint() {
        return {
            flow: 'customer_to_traveler and traveler_to_customer',
        };
    }
    async findByUser(userId, requester) {
        if (requester.sub !== userId && !['admin', 'support'].includes(requester.role)) {
            throw new common_1.ForbiddenException('No tienes permiso para ver estas calificaciones.');
        }
        return this.prisma.rating.findMany({
            where: { toUserId: userId },
            orderBy: { createdAt: 'desc' },
        });
    }
    async create(payload) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: payload.shipmentId },
            include: { assignedTraveler: true, customer: true },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        const fromUser = await this.prisma.user.findUnique({
            where: { id: payload.fromUserId },
        });
        if (!fromUser) {
            throw new common_1.NotFoundException('Usuario emisor no encontrado.');
        }
        let toUserId = null;
        if (payload.fromUserId == shipment.customerId) {
            toUserId = shipment.assignedTravelerId;
        }
        else if (payload.fromUserId == shipment.assignedTravelerId) {
            toUserId = shipment.customerId;
        }
        if (!toUserId) {
            throw new common_1.BadRequestException('No se pudo determinar a quién pertenece esta calificación.');
        }
        const existing = await this.prisma.rating.findFirst({
            where: {
                shipmentId: payload.shipmentId,
                fromUserId: payload.fromUserId,
                toUserId,
            },
        });
        if (existing) {
            throw new common_1.BadRequestException('Ya existe una calificación enviada para este envío.');
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
        await this.notificationsService.sendPush(toUserId, 'Nueva calificación', `Recibiste ${payload.stars} estrella(s) por el envío ${payload.shipmentId}.`, 'rating', payload.shipmentId);
        return rating;
    }
};
exports.RatingsService = RatingsService;
exports.RatingsService = RatingsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notifications_service_1.NotificationsService])
], RatingsService);
//# sourceMappingURL=ratings.service.js.map