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
exports.TrackingService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
const realtime_gateway_1 = require("../realtime/realtime.gateway");
let TrackingService = class TrackingService {
    constructor(prisma, realtimeGateway) {
        this.prisma = prisma;
        this.realtimeGateway = realtimeGateway;
    }
    haversineKm(lat1, lon1, lat2, lon2) {
        const toRad = (value) => (value * Math.PI) / 180;
        const earthRadiusKm = 6371;
        const dLat = toRad(lat2 - lat1);
        const dLon = toRad(lon2 - lon1);
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRad(lat1)) *
                Math.cos(toRad(lat2)) *
                Math.sin(dLon / 2) *
                Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadiusKm * c;
    }
    ensureShipmentAccess(shipment, requester) {
        const isPrivileged = ['admin', 'support'].includes(requester.role);
        const isParticipant = shipment.customerId === requester.sub || shipment.assignedTravelerId === requester.sub;
        if (!isPrivileged && !isParticipant) {
            throw new common_1.ForbiddenException('No tienes acceso a este envío.');
        }
    }
    async update(payload, requester) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: payload.shipmentId },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        const isPrivileged = ['admin', 'support'].includes(requester.role);
        if (shipment.assignedTravelerId && shipment.assignedTravelerId !== payload.travelerId && !isPrivileged) {
            throw new common_1.BadRequestException('Solo el viajero asignado puede reportar tracking.');
        }
        const trackingPoint = await this.prisma.trackingPoint.create({
            data: {
                shipmentId: payload.shipmentId,
                travelerId: payload.travelerId,
                lat: payload.lat,
                lng: payload.lng,
                accuracyM: payload.accuracyM,
            },
        });
        await this.prisma.shipmentEvent.create({
            data: {
                shipmentId: payload.shipmentId,
                eventType: payload.checkpoint ? `checkpoint_${payload.checkpoint}` : 'tracking_update',
                eventPayload: {
                    lat: payload.lat,
                    lng: payload.lng,
                    accuracyM: payload.accuracyM,
                    checkpoint: payload.checkpoint ?? null,
                },
            },
        });
        this.realtimeGateway.emitTrackingUpdated(payload.shipmentId, {
            shipmentId: payload.shipmentId,
            trackingPoint,
            checkpoint: payload.checkpoint ?? null,
        });
        return trackingPoint;
    }
    async getLatestLocation(shipmentId, requester) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: shipmentId },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        this.ensureShipmentAccess(shipment, requester);
        const latest = await this.prisma.trackingPoint.findFirst({
            where: { shipmentId },
            orderBy: { recordedAt: 'desc' },
        });
        if (!latest) {
            throw new common_1.NotFoundException('No hay tracking todavía para este envío.');
        }
        return latest;
    }
    async getTimeline(shipmentId, requester) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: shipmentId },
            include: {
                events: true,
                trackingPoints: true,
            },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        this.ensureShipmentAccess(shipment, requester);
        const timeline = [
            ...shipment.events.map((event) => ({
                kind: 'event',
                at: event.createdAt,
                type: event.eventType,
                payload: event.eventPayload,
            })),
            ...shipment.trackingPoints.map((point) => ({
                kind: 'tracking',
                at: point.recordedAt,
                type: 'tracking_point',
                payload: {
                    lat: point.lat,
                    lng: point.lng,
                    accuracyM: point.accuracyM,
                },
            })),
        ].sort((a, b) => new Date(a.at).getTime() - new Date(b.at).getTime());
        return {
            shipmentId,
            currentStatus: shipment.status,
            timeline,
        };
    }
    async getEta(shipmentId, requester) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: shipmentId },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        this.ensureShipmentAccess(shipment, requester);
        const latest = await this.prisma.trackingPoint.findFirst({
            where: { shipmentId },
            orderBy: { recordedAt: 'desc' },
        });
        if (!latest || shipment.deliveryLat == null || shipment.deliveryLng == null) {
            return {
                shipmentId,
                etaMinutes: null,
                reason: 'Faltan coordenadas de entrega o tracking suficiente.',
            };
        }
        const distanceKm = this.haversineKm(Number(latest.lat), Number(latest.lng), Number(shipment.deliveryLat), Number(shipment.deliveryLng));
        const assumedSpeedKmH = 45;
        const etaMinutes = Math.round((distanceKm / assumedSpeedKmH) * 60);
        return {
            shipmentId,
            distanceKm,
            etaMinutes,
        };
    }
    decodeGooglePolyline(encoded) {
        const coordinates = [];
        let index = 0;
        let lat = 0;
        let lng = 0;
        while (index < encoded.length) {
            let result = 0;
            let shift = 0;
            let byte = 0;
            do {
                byte = encoded.charCodeAt(index++) - 63;
                result |= (byte & 0x1f) << shift;
                shift += 5;
            } while (byte >= 0x20);
            const deltaLat = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
            lat += deltaLat;
            result = 0;
            shift = 0;
            do {
                byte = encoded.charCodeAt(index++) - 63;
                result |= (byte & 0x1f) << shift;
                shift += 5;
            } while (byte >= 0x20);
            const deltaLng = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
            lng += deltaLng;
            coordinates.push({
                lat: lat / 1e5,
                lng: lng / 1e5,
            });
        }
        return coordinates;
    }
    async getGoogleDirectionsRoute(origin, destination) {
        const mapsApiKey = process.env.MAPS_API_KEY?.trim();
        if (!mapsApiKey) {
            return null;
        }
        const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
        url.searchParams.set('origin', `${origin.lat},${origin.lng}`);
        url.searchParams.set('destination', `${destination.lat},${destination.lng}`);
        url.searchParams.set('mode', 'driving');
        url.searchParams.set('key', mapsApiKey);
        const response = await fetch(url.toString());
        if (!response.ok) {
            return null;
        }
        const data = (await response.json());
        if (data.status !== 'OK' || !Array.isArray(data.routes) || data.routes.length == 0) {
            return null;
        }
        const route = data.routes[0];
        const encoded = route.overview_polyline?.points;
        if (typeof encoded !== 'string' || encoded.length === 0) {
            return null;
        }
        const leg = Array.isArray(route.legs) && route.legs.length > 0 ? route.legs[0] : null;
        return {
            provider: 'google-directions',
            polyline: this.decodeGooglePolyline(encoded),
            distanceKm: leg?.distance?.value != null ? Number(leg.distance.value) / 1000 : null,
            durationMinutes: leg?.duration?.value != null ? Math.round(Number(leg.duration.value) / 60) : null,
        };
    }
    async getRoute(shipmentId, requester) {
        const shipment = await this.prisma.shipment.findUnique({
            where: { id: shipmentId },
        });
        if (!shipment) {
            throw new common_1.NotFoundException('Envío no encontrado.');
        }
        this.ensureShipmentAccess(shipment, requester);
        const latest = await this.prisma.trackingPoint.findFirst({
            where: { shipmentId },
            orderBy: { recordedAt: 'desc' },
        });
        const points = [];
        if (shipment.pickupLat != null && shipment.pickupLng != null) {
            points.push({
                lat: Number(shipment.pickupLat),
                lng: Number(shipment.pickupLng),
                kind: 'pickup',
            });
        }
        if (latest) {
            points.push({
                lat: Number(latest.lat),
                lng: Number(latest.lng),
                kind: 'current',
            });
        }
        if (shipment.deliveryLat != null && shipment.deliveryLng != null) {
            points.push({
                lat: Number(shipment.deliveryLat),
                lng: Number(shipment.deliveryLng),
                kind: 'delivery',
            });
        }
        const fallbackPolyline = points.map((point) => ({
            lat: point.lat,
            lng: point.lng,
        }));
        let fallbackDistanceKm = null;
        if (points.length >= 2) {
            fallbackDistanceKm = 0;
            for (let i = 0; i < points.length - 1; i += 1) {
                fallbackDistanceKm += this.haversineKm(points[i].lat, points[i].lng, points[i + 1].lat, points[i + 1].lng);
            }
        }
        const originPoint = latest != null
            ? { lat: Number(latest.lat), lng: Number(latest.lng) }
            : shipment.pickupLat != null && shipment.pickupLng != null
                ? { lat: Number(shipment.pickupLat), lng: Number(shipment.pickupLng) }
                : null;
        const destinationPoint = shipment.deliveryLat != null && shipment.deliveryLng != null
            ? { lat: Number(shipment.deliveryLat), lng: Number(shipment.deliveryLng) }
            : null;
        const googleRoute = originPoint != null && destinationPoint != null
            ? await this.getGoogleDirectionsRoute(originPoint, destinationPoint)
            : null;
        const effectiveGoogleRoute = googleRoute != null && googleRoute.polyline.length >= 2 ? googleRoute : null;
        const effectivePolyline = effectiveGoogleRoute?.polyline ?? fallbackPolyline;
        return {
            shipmentId,
            hasRoute: effectivePolyline.length >= 2,
            provider: effectiveGoogleRoute?.provider ?? 'estimated-segments',
            polyline: effectivePolyline,
            points,
            distanceKm: effectiveGoogleRoute?.distanceKm ?? fallbackDistanceKm,
            durationMinutes: effectiveGoogleRoute?.durationMinutes,
            reason: effectivePolyline.length >= 2
                ? null
                : 'Faltan coordenadas de origen o destino para trazar la ruta.',
        };
    }
};
exports.TrackingService = TrackingService;
exports.TrackingService = TrackingService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        realtime_gateway_1.RealtimeGateway])
], TrackingService);
//# sourceMappingURL=tracking.service.js.map