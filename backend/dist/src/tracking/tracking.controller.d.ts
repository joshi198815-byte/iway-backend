import { TrackingService } from './tracking.service';
import { UpdateTrackingDto } from './dto/update-tracking.dto';
export declare class TrackingController {
    private readonly trackingService;
    constructor(trackingService: TrackingService);
    update(body: UpdateTrackingDto, req: any): Promise<{
        id: string;
        shipmentId: string;
        travelerId: string;
        lat: import("@prisma/client/runtime/library").Decimal;
        lng: import("@prisma/client/runtime/library").Decimal;
        accuracyM: import("@prisma/client/runtime/library").Decimal | null;
        recordedAt: Date;
    }>;
    getLatest(shipmentId: string, req: any): Promise<{
        id: string;
        shipmentId: string;
        travelerId: string;
        lat: import("@prisma/client/runtime/library").Decimal;
        lng: import("@prisma/client/runtime/library").Decimal;
        accuracyM: import("@prisma/client/runtime/library").Decimal | null;
        recordedAt: Date;
    }>;
    getTimeline(shipmentId: string, req: any): Promise<{
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
    getEta(shipmentId: string, req: any): Promise<{
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
    getRoute(shipmentId: string, req: any): Promise<{
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
