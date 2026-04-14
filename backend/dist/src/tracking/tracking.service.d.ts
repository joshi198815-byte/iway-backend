import { PrismaService } from '../database/prisma/prisma.service';
import { UpdateTrackingDto } from './dto/update-tracking.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';
export declare class TrackingService {
    private readonly prisma;
    private readonly realtimeGateway;
    constructor(prisma: PrismaService, realtimeGateway: RealtimeGateway);
    private haversineKm;
    private ensureShipmentAccess;
    update(payload: UpdateTrackingDto, requester: {
        sub: string;
        role: string;
    }): Promise<{
        id: string;
        shipmentId: string;
        travelerId: string;
        lat: import("@prisma/client/runtime/library").Decimal;
        lng: import("@prisma/client/runtime/library").Decimal;
        accuracyM: import("@prisma/client/runtime/library").Decimal | null;
        recordedAt: Date;
    }>;
    getLatestLocation(shipmentId: string, requester: {
        sub: string;
        role: string;
    }): Promise<{
        id: string;
        shipmentId: string;
        travelerId: string;
        lat: import("@prisma/client/runtime/library").Decimal;
        lng: import("@prisma/client/runtime/library").Decimal;
        accuracyM: import("@prisma/client/runtime/library").Decimal | null;
        recordedAt: Date;
    }>;
    getTimeline(shipmentId: string, requester: {
        sub: string;
        role: string;
    }): Promise<{
        shipmentId: string;
        currentStatus: import(".prisma/client").$Enums.ShipmentStatus;
        timeline: ({
            kind: string;
            at: Date;
            type: string;
            payload: import("@prisma/client/runtime/library").JsonValue;
        } | {
            kind: string;
            at: Date;
            type: string;
            payload: {
                lat: import("@prisma/client/runtime/library").Decimal;
                lng: import("@prisma/client/runtime/library").Decimal;
                accuracyM: import("@prisma/client/runtime/library").Decimal | null;
            };
        })[];
    }>;
    getEta(shipmentId: string, requester: {
        sub: string;
        role: string;
    }): Promise<{
        shipmentId: string;
        etaMinutes: null;
        reason: string;
        distanceKm?: undefined;
    } | {
        shipmentId: string;
        distanceKm: number;
        etaMinutes: number;
        reason?: undefined;
    }>;
    private decodeGooglePolyline;
    private getGoogleDirectionsRoute;
    getRoute(shipmentId: string, requester: {
        sub: string;
        role: string;
    }): Promise<{
        shipmentId: string;
        hasRoute: boolean;
        provider: string;
        polyline: {
            lat: number;
            lng: number;
        }[];
        points: {
            lat: number;
            lng: number;
            kind: string;
        }[];
        distanceKm: number | null;
        durationMinutes: number | null | undefined;
        reason: string | null;
    }>;
}
