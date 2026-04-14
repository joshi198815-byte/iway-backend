import { PrismaService } from '../database/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
export declare class DisputesService {
    private readonly prisma;
    private readonly notificationsService;
    constructor(prisma: PrismaService, notificationsService: NotificationsService);
    create(payload: {
        shipmentId: string;
        reason: string;
        context?: string;
    }, requester: {
        sub: string;
        role: string;
    }): Promise<{
        shipment: {
            status: import(".prisma/client").$Enums.ShipmentStatus;
            id: string;
            createdAt: Date;
            description: string | null;
            customerId: string;
            assignedTravelerId: string | null;
            direction: import(".prisma/client").$Enums.ShipmentDirection;
            originCountryCode: string;
            destinationCountryCode: string;
            packageType: string;
            packageCategory: string | null;
            declaredValue: import("@prisma/client/runtime/library").Decimal;
            weightLb: import("@prisma/client/runtime/library").Decimal | null;
            receiverName: string;
            receiverPhone: string;
            receiverAddress: string;
            insuranceEnabled: boolean;
            insuranceAmount: import("@prisma/client/runtime/library").Decimal;
            pickupLat: import("@prisma/client/runtime/library").Decimal | null;
            pickupLng: import("@prisma/client/runtime/library").Decimal | null;
            deliveryLat: import("@prisma/client/runtime/library").Decimal | null;
            deliveryLng: import("@prisma/client/runtime/library").Decimal | null;
            antiFraudScore: number;
            updatedAt: Date;
        };
        opener: {
            fullName: string;
            email: string;
        };
    } & {
        status: string;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        shipmentId: string;
        reason: string;
        resolution: string | null;
        openedBy: string;
    }>;
    listMine(requester: {
        sub: string;
        role: string;
    }): Promise<({
        shipment: {
            status: import(".prisma/client").$Enums.ShipmentStatus;
            id: string;
            createdAt: Date;
            description: string | null;
            customerId: string;
            assignedTravelerId: string | null;
            direction: import(".prisma/client").$Enums.ShipmentDirection;
            originCountryCode: string;
            destinationCountryCode: string;
            packageType: string;
            packageCategory: string | null;
            declaredValue: import("@prisma/client/runtime/library").Decimal;
            weightLb: import("@prisma/client/runtime/library").Decimal | null;
            receiverName: string;
            receiverPhone: string;
            receiverAddress: string;
            insuranceEnabled: boolean;
            insuranceAmount: import("@prisma/client/runtime/library").Decimal;
            pickupLat: import("@prisma/client/runtime/library").Decimal | null;
            pickupLng: import("@prisma/client/runtime/library").Decimal | null;
            deliveryLat: import("@prisma/client/runtime/library").Decimal | null;
            deliveryLng: import("@prisma/client/runtime/library").Decimal | null;
            antiFraudScore: number;
            updatedAt: Date;
        };
        opener: {
            fullName: string;
            email: string;
        };
    } & {
        status: string;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        shipmentId: string;
        reason: string;
        resolution: string | null;
        openedBy: string;
    })[]>;
    getQueue(requester: {
        sub: string;
        role: string;
    }): Promise<({
        shipment: {
            status: import(".prisma/client").$Enums.ShipmentStatus;
            id: string;
            createdAt: Date;
            description: string | null;
            customerId: string;
            assignedTravelerId: string | null;
            direction: import(".prisma/client").$Enums.ShipmentDirection;
            originCountryCode: string;
            destinationCountryCode: string;
            packageType: string;
            packageCategory: string | null;
            declaredValue: import("@prisma/client/runtime/library").Decimal;
            weightLb: import("@prisma/client/runtime/library").Decimal | null;
            receiverName: string;
            receiverPhone: string;
            receiverAddress: string;
            insuranceEnabled: boolean;
            insuranceAmount: import("@prisma/client/runtime/library").Decimal;
            pickupLat: import("@prisma/client/runtime/library").Decimal | null;
            pickupLng: import("@prisma/client/runtime/library").Decimal | null;
            deliveryLat: import("@prisma/client/runtime/library").Decimal | null;
            deliveryLng: import("@prisma/client/runtime/library").Decimal | null;
            antiFraudScore: number;
            updatedAt: Date;
        };
        opener: {
            fullName: string;
            email: string;
        };
    } & {
        status: string;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        shipmentId: string;
        reason: string;
        resolution: string | null;
        openedBy: string;
    })[]>;
    resolve(disputeId: string, payload: {
        status: 'resolved' | 'rejected' | 'escalated';
        resolution?: string;
    }, requester: {
        sub: string;
        role: string;
    }): Promise<{
        shipment: {
            status: import(".prisma/client").$Enums.ShipmentStatus;
            id: string;
            createdAt: Date;
            description: string | null;
            customerId: string;
            assignedTravelerId: string | null;
            direction: import(".prisma/client").$Enums.ShipmentDirection;
            originCountryCode: string;
            destinationCountryCode: string;
            packageType: string;
            packageCategory: string | null;
            declaredValue: import("@prisma/client/runtime/library").Decimal;
            weightLb: import("@prisma/client/runtime/library").Decimal | null;
            receiverName: string;
            receiverPhone: string;
            receiverAddress: string;
            insuranceEnabled: boolean;
            insuranceAmount: import("@prisma/client/runtime/library").Decimal;
            pickupLat: import("@prisma/client/runtime/library").Decimal | null;
            pickupLng: import("@prisma/client/runtime/library").Decimal | null;
            deliveryLat: import("@prisma/client/runtime/library").Decimal | null;
            deliveryLng: import("@prisma/client/runtime/library").Decimal | null;
            antiFraudScore: number;
            updatedAt: Date;
        };
        opener: {
            fullName: string;
            email: string;
        };
    } & {
        status: string;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        shipmentId: string;
        reason: string;
        resolution: string | null;
        openedBy: string;
    }>;
}
