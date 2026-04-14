import { DisputesService } from './disputes.service';
import { CreateDisputeDto } from './dto/create-dispute.dto';
import { ResolveDisputeDto } from './dto/resolve-dispute.dto';
export declare class DisputesController {
    private readonly disputesService;
    constructor(disputesService: DisputesService);
    create(body: CreateDisputeDto, req: any): Promise<{
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
    listMine(req: any): Promise<({
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
    getQueue(req: any): Promise<({
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
    resolve(disputeId: string, body: ResolveDisputeDto, req: any): Promise<{
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
