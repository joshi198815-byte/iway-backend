import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { UpdateTrackingDto } from './dto/update-tracking.dto';

type UpdateTrackingPayload = UpdateTrackingDto & { travelerId: string };
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

  async update(payload: UpdateTrackingPayload, requester: { sub: string; role: string }) {
    const shipment = await this.prisma.shipment.findUnique({
      where: { id: payload.shipmentId },
    });

    if (!shipment) {
      throw new NotFoundException('Envío no encontrado.');
    }

    const isPrivileged = ['admin', 'support'].includes(requester.role);
    const isAssignedTraveler = shipment.assignedTravelerId === requester.sub;

    if (!isPrivileged) {
      if (!shipment.assignedTravelerId || !isAssignedTraveler || payload.travelerId !== requester.sub) {
        throw new ForbiddenException('Solo el viajero asignado puede reportar tracking.');
      }
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

  private readonly destinationAirports = {
    GT: [
      { code: 'GUA', name: 'La Aurora International Airport', lat: 14.5833, lng: -90.5275 },
    ],
    US: [
      { code: 'MIA', name: 'Miami International Airport', lat: 25.7959, lng: -80.2871 },
      { code: 'IAH', name: 'Houston Intercontinental Airport', lat: 29.9902, lng: -95.3368 },
      { code: 'ATL', name: 'Hartsfield-Jackson Atlanta International Airport', lat: 33.6407, lng: -84.4277 },
      { code: 'DFW', name: 'Dallas/Fort Worth International Airport', lat: 32.8998, lng: -97.0403 },
      { code: 'LAX', name: 'Los Angeles International Airport', lat: 33.9416, lng: -118.4085 },
      { code: 'JFK', name: 'John F. Kennedy International Airport', lat: 40.6413, lng: -73.7781 },
    ],
  } as const;

  private resolveNearestDestinationAirport(
    countryCode: string,
    destination: { lat: number; lng: number },
  ) {
    const options = [
      ...(this.destinationAirports[countryCode as keyof typeof this.destinationAirports] ?? []),
    ];
    if (options.length === 0) return null;

    return options.reduce((best, current) => {
      const bestDistance = this.haversineKm(best.lat, best.lng, destination.lat, destination.lng);
      const currentDistance = this.haversineKm(current.lat, current.lng, destination.lat, destination.lng);
      return currentDistance < bestDistance ? current : best;
    });
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

    const isInternationalGtUs =
      shipment.originCountryCode !== shipment.destinationCountryCode &&
      ['GT', 'US'].includes(shipment.originCountryCode) &&
      ['GT', 'US'].includes(shipment.destinationCountryCode);
    const destinationCountryReached = ['arrived', 'in_delivery', 'delivered'].includes(shipment.status);

    let effectiveGoogleRoute: Awaited<ReturnType<typeof this.getGoogleDirectionsRoute>> | null = null;
    let effectivePolyline = fallbackPolyline;
    let effectiveDistanceKm = fallbackDistanceKm;
    let effectiveDurationMinutes: number | null | undefined = null;
    let reason: string | null = null;

    if (isInternationalGtUs) {
      if (destinationPoint != null && destinationCountryReached) {
        const airport = this.resolveNearestDestinationAirport(shipment.destinationCountryCode, destinationPoint);
        if (airport) {
          points.push({ lat: airport.lat, lng: airport.lng, kind: 'airport' });
          const airportRoute = await this.getGoogleDirectionsRoute(
            { lat: airport.lat, lng: airport.lng },
            destinationPoint,
          );
          effectiveGoogleRoute = airportRoute != null && airportRoute.polyline.length >= 2 ? airportRoute : null;
          effectivePolyline = effectiveGoogleRoute?.polyline ?? [
            { lat: airport.lat, lng: airport.lng },
            destinationPoint,
          ];
          effectiveDistanceKm = effectiveGoogleRoute?.distanceKm ?? this.haversineKm(airport.lat, airport.lng, destinationPoint.lat, destinationPoint.lng);
          effectiveDurationMinutes = effectiveGoogleRoute?.durationMinutes ?? null;
          reason = null;
        } else {
          effectivePolyline = [];
          effectiveDistanceKm = null;
          reason = 'No se encontró un aeropuerto internacional de referencia para el tramo final.';
        }
      } else {
        effectivePolyline = [];
        effectiveDistanceKm = null;
        reason = 'Ruta internacional en tránsito aéreo. El tramo terrestre final aparecerá al llegar al país de destino.';
      }
    } else if (originPoint != null && destinationPoint != null) {
      const googleRoute = await this.getGoogleDirectionsRoute(originPoint, destinationPoint);
      effectiveGoogleRoute = googleRoute != null && googleRoute.polyline.length >= 2 ? googleRoute : null;
      effectivePolyline = effectiveGoogleRoute?.polyline ?? fallbackPolyline;
      effectiveDistanceKm = effectiveGoogleRoute?.distanceKm ?? fallbackDistanceKm;
      effectiveDurationMinutes = effectiveGoogleRoute?.durationMinutes;
      reason = effectivePolyline.length >= 2 ? null : 'Faltan coordenadas de origen o destino para trazar la ruta.';
    } else {
      reason = 'Faltan coordenadas de origen o destino para trazar la ruta.';
    }

    return {
      shipmentId,
      hasRoute: effectivePolyline.length >= 2,
      provider: effectiveGoogleRoute?.provider ?? (isInternationalGtUs ? 'destination-airport-segment' : 'estimated-segments'),
      polyline: effectivePolyline,
      points,
      distanceKm: effectiveDistanceKm,
      durationMinutes: effectiveDurationMinutes,
      reason,
    };
  }
}
