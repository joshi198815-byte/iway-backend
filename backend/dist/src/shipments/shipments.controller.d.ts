import { ShipmentsService } from './shipments.service';
import { CreateShipmentDto } from './dto/create-shipment.dto';
import { UpdateShipmentStatusDto } from './dto/update-shipment-status.dto';
export declare class ShipmentsController {
    private readonly shipmentsService;
    constructor(shipmentsService: ShipmentsService);
    create(body: CreateShipmentDto, req: any): Promise<{
        images: {
            id: string;
            createdAt: Date;
            kind: import(".prisma/client").$Enums.ShipmentImageKind;
            shipmentId: string;
            imageUrl: string;
        }[];
    } & {
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
    }>;
    findAvailable(req: any): Promise<any[]>;
    findAll(req: any): Promise<({
        images: {
            id: string;
            createdAt: Date;
            kind: import(".prisma/client").$Enums.ShipmentImageKind;
            shipmentId: string;
            imageUrl: string;
        }[];
        offers: {
            message: string | null;
            status: import(".prisma/client").$Enums.OfferStatus;
            id: string;
            createdAt: Date;
            shipmentId: string;
            travelerId: string;
            price: import("@prisma/client/runtime/library").Decimal;
        }[];
        commission: {
            status: import(".prisma/client").$Enums.CommissionStatus;
            id: string;
            shipmentId: string;
            travelerId: string;
            commissionAmount: import("@prisma/client/runtime/library").Decimal;
            generatedAt: Date;
            dueDate: Date | null;
            paidAt: Date | null;
            settlementWeek: Date | null;
            notes: string | null;
        } | null;
    } & {
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
    })[]>;
    findOne(id: string): Promise<{
        images: {
            id: string;
            createdAt: Date;
            kind: import(".prisma/client").$Enums.ShipmentImageKind;
            shipmentId: string;
            imageUrl: string;
        }[];
        events: {
            id: string;
            createdAt: Date;
            shipmentId: string;
            createdBy: string | null;
            eventType: string;
            eventPayload: import("@prisma/client/runtime/library").JsonValue | null;
        }[];
        offers: {
            message: string | null;
            status: import(".prisma/client").$Enums.OfferStatus;
            id: string;
            createdAt: Date;
            shipmentId: string;
            travelerId: string;
            price: import("@prisma/client/runtime/library").Decimal;
        }[];
        commission: {
            status: import(".prisma/client").$Enums.CommissionStatus;
            id: string;
            shipmentId: string;
            travelerId: string;
            commissionAmount: import("@prisma/client/runtime/library").Decimal;
            generatedAt: Date;
            dueDate: Date | null;
            paidAt: Date | null;
            settlementWeek: Date | null;
            notes: string | null;
        } | null;
    } & {
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
    }>;
    updateStatus(id: string, body: UpdateShipmentStatusDto, req: any): Promise<{
        images: {
            id: string;
            createdAt: Date;
            kind: import(".prisma/client").$Enums.ShipmentImageKind;
            shipmentId: string;
            imageUrl: string;
        }[];
        events: {
            id: string;
            createdAt: Date;
            shipmentId: string;
            createdBy: string | null;
            eventType: string;
            eventPayload: import("@prisma/client/runtime/library").JsonValue | null;
        }[];
        offers: {
            message: string | null;
            status: import(".prisma/client").$Enums.OfferStatus;
            id: string;
            createdAt: Date;
            shipmentId: string;
            travelerId: string;
            price: import("@prisma/client/runtime/library").Decimal;
        }[];
        commission: {
            status: import(".prisma/client").$Enums.CommissionStatus;
            id: string;
            shipmentId: string;
            travelerId: string;
            commissionAmount: import("@prisma/client/runtime/library").Decimal;
            generatedAt: Date;
            dueDate: Date | null;
            paidAt: Date | null;
            settlementWeek: Date | null;
            notes: string | null;
        } | null;
    } & {
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
    }>;
}
