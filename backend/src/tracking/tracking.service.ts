import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { UpdateTrackingDto } from './dto/update-tracking.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class TrackingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

  private haversineKm(lat1: number, lon1: number, lat2: number, lon2: number) {
    const toRad = (value: number) => (value * Math.PI) / 180;
    const earthRadiusKm = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  private ensureShipmentAccess(
    shipment: { customerId: string; assignedTravelerId: string | null },
    requester: { sub: string; role: string },
  ) {
    const isPrivileged = ['admin', 'support'].includes(requester.role);
    const isParticipant =
      shipment.customerId === requester.sub || shipment.assignedTravelerId === requester.sub;

    if (!isPrivileged && !isParticipant) {
      throw new ForbiddenException('No tienes acceso a este envío.');
    }
  }

  async update(payload: UpdateTrackingDto, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: payload.shipmentId },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    const isPrivileged = ['admin', 'support'].includes(requester.role);

    if (shipment.assignedTravelerId && shipment.assignedTravelerId !== payload.travelerId && !isPrivileged) {
      throw new BadRequestException('Solo el viajero asignado puede reportar tracking.');
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

  async getLatestLocation(shipmentId: string, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: shipmentId },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    this.ensureShipmentAccess(shipment, requester);

    const latest = await this.prisma.trackingPoint.findFirst({
      where: { shipmentId },
      orderBy: { recordedAt: 'desc' },
    });

    if (!latest) {
      throw new NotFoundException('No hay tracking todavía para este envío.');
    }

    return latest;
  }

  async getTimeline(shipmentId: string, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: shipmentId },
      include: {
        events: true,
        trackingPoints: true,
      },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
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

  async getEta(shipmentId: string, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: shipmentId },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
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

    const distanceKm = this.haversineKm(
      Number(latest.lat),
      Number(latest.lng),
      Number(shipment.deliveryLat),
      Number(shipment.deliveryLng),
    );

    const assumedSpeedKmH = 45;
    const etaMinutes = Math.round((distanceKm / assumedSpeedKmH) * 60);

    return {
      shipmentId,
      distanceKm,
      etaMinutes,
    };
  }

  private decodeGooglePolyline(encoded: string) {
    const coordinates: Array<{ lat: number; lng: number }> = [];
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

  private async getGoogleDirectionsRoute(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
  ) {
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

    const data = (await response.json()) as any;
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
      durationMinutes:
        leg?.duration?.value != null ? Math.round(Number(leg.duration.value) / 60) : null,
    };
  }

  async getRoute(shipmentId: string, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: shipmentId },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    this.ensureShipmentAccess(shipment, requester);

    const latest = await this.prisma.trackingPoint.findFirst({
      where: { shipmentId },
      orderBy: { recordedAt: 'desc' },
    });

    const points: Array<{ lat: number; lng: number; kind: string }> = [];

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

    let fallbackDistanceKm: number | null = null;
    if (points.length >= 2) {
      fallbackDistanceKm = 0;
      for (let i = 0; i < points.length - 1; i += 1) {
        fallbackDistanceKm += this.haversineKm(
          points[i].lat,
          points[i].lng,
          points[i + 1].lat,
          points[i + 1].lng,
        );
      }
    }

    const originPoint =
      latest != null
        ? { lat: Number(latest.lat), lng: Number(latest.lng) }
        : shipment.pickupLat != null && shipment.pickupLng != null
          ? { lat: Number(shipment.pickupLat), lng: Number(shipment.pickupLng) }
          : null;
    const destinationPoint =
      shipment.deliveryLat != null && shipment.deliveryLng != null
        ? { lat: Number(shipment.deliveryLat), lng: Number(shipment.deliveryLng) }
        : null;

    const googleRoute =
      originPoint != null && destinationPoint != null
        ? await this.getGoogleDirectionsRoute(originPoint, destinationPoint)
        : null;
    const effectiveGoogleRoute =
      googleRoute != null && googleRoute.polyline.length >= 2 ? googleRoute : null;
    const effectivePolyline = effectiveGoogleRoute?.polyline ?? fallbackPolyline;

    return {
      shipmentId,
      hasRoute: effectivePolyline.length >= 2,
      provider: effectiveGoogleRoute?.provider ?? 'estimated-segments',
      polyline: effectivePolyline,
      points,
      distanceKm: effectiveGoogleRoute?.distanceKm ?? fallbackDistanceKm,
      durationMinutes: effectiveGoogleRoute?.durationMinutes,
      reason:
        effectivePolyline.length >= 2
          ? null
          : 'Faltan coordenadas de origen o destino para trazar la ruta.',
    };
  }
}
