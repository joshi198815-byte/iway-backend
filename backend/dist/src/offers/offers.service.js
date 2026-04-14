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
exports.OffersService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../database/prisma/prisma.service");
const notifications_service_1 = require("../notifications/notifications.service");
const realtime_gateway_1 = require("../realtime/realtime.gateway");
const runtime_observability_1 = require("../common/observability/runtime-observability");
let OffersService = class OffersService {
    constructor(prisma, notificationsService, realtimeGateway) {
        this.prisma = prisma;
        this.notificationsService = notificationsService;
        this.realtimeGateway = realtimeGateway;
    }
    normalizeDecimal(value) {
        const parsed = Number(value ?? 0);
        return Number.isFinite(parsed) ? parsed : 0;
    }
    scoreOffer(params) {
        let score = 35;
        if (params.minPrice > 0) {
            const competitiveness = Math.max(0.35, Math.min(1.1, params.minPrice / Math.max(params.price, 1)));
            score += competitiveness * 22;
        }
        score += Math.min(18, params.verificationScore * 0.18);
        score += Math.min(14, params.ratingAvg * 3.2);
        score += Math.min(12, params.deliveredCount * 1.5);
        score += Math.min(10, params.acceptanceRate * 10);
        if (params.travelerStatus === 'verified')
            score += 8;
        if (params.travelerStatus === 'pending')
            score += 2;
        if (params.currentDebt > 0)
            score -= Math.min(8, params.currentDebt / 20);
        return Math.max(1, Math.min(100, Math.round(score)));
    }
    async create(payload) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: payload.shipmentId },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        const traveler = await this.prisma.travelerProfile.findUnique({
            where: { userId: payload.travelerId },
        });
        if (!traveler) {
            throw new common_1.BadRequestException('El viajero no existe o no está configurado.');
        }
        if (traveler.status === client_1.TravelerStatus.blocked_for_debt) {
            throw new common_1.BadRequestException('El viajero está bloqueado por deuda.');
        }
        if (traveler.status === client_1.TravelerStatus.blocked || traveler.status === client_1.TravelerStatus.rejected) {
            throw new common_1.BadRequestException('Tu perfil no puede ofertar hasta completar la revisión KYC.');
        }
        if (traveler.status !== client_1.TravelerStatus.verified && (traveler.verificationScore ?? 0) < 65) {
            throw new common_1.BadRequestException('Tu perfil necesita una validación KYC más sólida antes de ofertar.');
        }
        const offer = await this.prisma.offer.create({
            data: {
                shipmentId: payload.shipmentId,
                travelerId: payload.travelerId,
                price: payload.price,
            },
        });
        await this.prisma.shipment.update({
            where: { id: payload.shipmentId },
            data: {
                status: client_1.ShipmentStatus.offered,
            },
        });
        await this.notificationsService.sendPush(shipment.customerId, 'Nueva oferta recibida', `Un viajero envió una oferta para tu envío ${payload.shipmentId}.`, 'offer', payload.shipmentId);
        this.realtimeGateway.emitOfferUpdated(payload.shipmentId, {
            shipmentId: payload.shipmentId,
            action: 'created',
            offer,
        });
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'offer_created',
            entityId: offer.id,
            actorId: payload.travelerId,
            shipmentId: payload.shipmentId,
            metadata: { price: Number(offer.price) },
        });
        return offer;
    }
    async findByShipment(shipmentId) {
        const offers = await this.prisma.offer.findMany({
            where: { shipmentId },
            include: {
                traveler: {
                    include: {
                        travelerProfile: true,
                    },
                },
            },
            orderBy: { createdAt: 'asc' },
        });
        if (offers.length === 0) {
            return offers;
        }
        const travelerIds = [...new Set(offers.map((offer) => offer.travelerId))];
        const [acceptedOffers, deliveredShipments] = await Promise.all([
            this.prisma.offer.findMany({
                where: { travelerId: { in: travelerIds }, status: client_1.OfferStatus.accepted },
                select: { travelerId: true },
            }),
            this.prisma.shipment.findMany({
                where: { assignedTravelerId: { in: travelerIds }, status: client_1.ShipmentStatus.delivered },
                select: { assignedTravelerId: true },
            }),
        ]);
        const acceptedByTraveler = acceptedOffers.reduce((acc, item) => {
            acc[item.travelerId] = (acc[item.travelerId] ?? 0) + 1;
            return acc;
        }, {});
        const deliveredByTraveler = deliveredShipments.reduce((acc, item) => {
            if (!item.assignedTravelerId)
                return acc;
            acc[item.assignedTravelerId] = (acc[item.assignedTravelerId] ?? 0) + 1;
            return acc;
        }, {});
        const minPrice = Math.min(...offers.map((offer) => this.normalizeDecimal(offer.price)));
        return offers
            .map((offer) => {
            const profile = offer.traveler.travelerProfile;
            const acceptedCount = acceptedByTraveler[offer.travelerId] ?? 0;
            const deliveredCount = deliveredByTraveler[offer.travelerId] ?? 0;
            const acceptanceRate = acceptedCount > 0 ? deliveredCount / acceptedCount : 0;
            const score = this.scoreOffer({
                price: this.normalizeDecimal(offer.price),
                minPrice,
                verificationScore: profile?.verificationScore ?? 0,
                ratingAvg: this.normalizeDecimal(profile?.ratingAvg),
                deliveredCount,
                acceptanceRate,
                travelerStatus: profile?.status ?? 'pending',
                currentDebt: this.normalizeDecimal(profile?.currentDebt),
            });
            const insights = [
                profile?.status === 'verified' ? 'Perfil verificado' : 'Perfil en revisión',
                deliveredCount > 0 ? `${deliveredCount} entregas cerradas` : 'Sin entregas cerradas aún',
                acceptanceRate >= 0.8 ? 'Muy buen cumplimiento' : acceptanceRate >= 0.5 ? 'Cumplimiento estable' : 'Cumplimiento por construir',
                this.normalizeDecimal(offer.price) === minPrice ? 'Precio más competitivo' : 'Precio comparado con otras ofertas',
            ];
            return {
                ...offer,
                travelerName: offer.traveler.fullName,
                travelerStatus: profile?.status ?? 'pending',
                travelerVerificationScore: profile?.verificationScore ?? 0,
                travelerRatingAvg: this.normalizeDecimal(profile?.ratingAvg),
                travelerRatingCount: profile?.ratingCount ?? 0,
                deliveredCount,
                acceptanceRate: Number(acceptanceRate.toFixed(2)),
                marketplaceScore: score,
                marketplaceTier: score >= 80 ? 'prime' : score >= 65 ? 'strong' : 'watch',
                marketplaceInsights: insights,
            };
        })
            .sort((a, b) => Number(b.marketplaceScore) - Number(a.marketplaceScore));
    }
    async acceptOffer(offerId, payload) {
        const offer = await this.prisma.offer.findUnique({
            where: { id: offerId },
            include: { shipment: true },
        });
        if (!offer) {
            throw new common_1.NotFoundException('Oferta no encontrada.');
        }
        if (offer.shipment.customerId !== payload.acceptedByCustomerId) {
            throw new common_1.BadRequestException('Solo el cliente dueño del envío puede aceptar esta oferta.');
        }
        await this.prisma.$transaction([
            this.prisma.offer.updateMany({
                where: {
                    shipmentId: offer.shipmentId,
                    id: { not: offerId },
                },
                data: {
                    status: client_1.OfferStatus.rejected,
                },
            }),
            this.prisma.offer.update({
                where: { id: offerId },
                data: {
                    status: client_1.OfferStatus.accepted,
                },
            }),
            this.prisma.shipment.update({
                where: { id: offer.shipmentId },
                data: {
                    status: client_1.ShipmentStatus.assigned,
                    assignedTravelerId: offer.travelerId,
                },
            }),
        ]);
        await this.prisma.chat.upsert({
            where: { shipmentId: offer.shipmentId },
            update: {},
            create: { shipmentId: offer.shipmentId },
        });
        await this.notificationsService.sendPush(offer.travelerId, 'Oferta aceptada', `Tu oferta para el envío ${offer.shipmentId} fue aceptada.`, 'offer_accepted', offer.shipmentId);
        await this.notificationsService.sendPush(offer.shipment.customerId, 'Envío asignado', `Tu envío ${offer.shipmentId} ya fue asignado a un viajero.`, 'shipment_assigned', offer.shipmentId);
        const acceptedOffer = await this.prisma.offer.findUnique({
            where: { id: offerId },
            include: { shipment: true },
        });
        this.realtimeGateway.emitOfferUpdated(offer.shipmentId, {
            shipmentId: offer.shipmentId,
            action: 'accepted',
            offerId,
            travelerId: offer.travelerId,
        });
        this.realtimeGateway.emitShipmentStatusChanged(offer.shipmentId, {
            shipmentId: offer.shipmentId,
            previousStatus: offer.shipment.status,
            nextStatus: 'assigned',
        });
        runtime_observability_1.runtimeObservability.recordBusinessEvent({
            type: 'offer_accepted',
            entityId: offerId,
            actorId: payload.acceptedByCustomerId,
            shipmentId: offer.shipmentId,
            metadata: { travelerId: offer.travelerId },
        });
        return acceptedOffer;
    }
};
exports.OffersService = OffersService;
exports.OffersService = OffersService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notifications_service_1.NotificationsService,
        realtime_gateway_1.RealtimeGateway])
], OffersService);
//# sourceMappingURL=offers.service.js.map