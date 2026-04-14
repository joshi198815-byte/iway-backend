import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { AcceptOfferDto } from './dto/accept-offer.dto';
export declare class OffersController {
    private readonly offersService;
    constructor(offersService: OffersService);
    create(body: CreateOfferDto, req: any): Promise<{
        message: string | null;
        status: import(".prisma/client").$Enums.OfferStatus;
        id: string;
        createdAt: Date;
        shipmentId: string;
        travelerId: string;
        price: import("@prisma/client/runtime/library").Decimal;
    }>;
    findByShipment(shipmentId: string): Promise<({
        traveler: {
            travelerProfile: {
                status: import(".prisma/client").$Enums.TravelerStatus;
                id: string;
                createdAt: Date;
                updatedAt: Date;
                userId: string;
                trustScore: number;
                travelerType: import(".prisma/client").$Enums.TravelerType;
                verificationScore: number;
                ratingAvg: import("@prisma/client/runtime/library").Decimal;
                ratingCount: number;
                dpiOrPassport: string | null;
                documentUrl: string | null;
                selfieUrl: string | null;
                currentDebt: import("@prisma/client/runtime/library").Decimal;
                preferredCutoffDay: number;
                weeklyBlockEnabled: boolean;
                payoutHoldEnabled: boolean;
                kycTier: import(".prisma/client").$Enums.KycTier;
                lastKycReviewAt: Date | null;
                blockedReason: string | null;
            } | null;
        } & {
            role: import(".prisma/client").$Enums.UserRole;
            status: import(".prisma/client").$Enums.UserStatus;
            id: string;
            createdAt: Date;
            updatedAt: Date;
            fullName: string;
            email: string;
            phone: string;
            passwordHash: string;
            countryCode: string | null;
            stateRegion: string | null;
            city: string | null;
            address: string | null;
            detectedCountryCode: string | null;
            phoneVerified: boolean;
            emailVerified: boolean;
        };
    } & {
        message: string | null;
        status: import(".prisma/client").$Enums.OfferStatus;
        id: string;
        createdAt: Date;
        shipmentId: string;
        travelerId: string;
        price: import("@prisma/client/runtime/library").Decimal;
    })[]>;
    accept(id: string, body: AcceptOfferDto, req: any): Promise<({
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
    } & {
        message: string | null;
        status: import(".prisma/client").$Enums.OfferStatus;
        id: string;
        createdAt: Date;
        shipmentId: string;
        travelerId: string;
        price: import("@prisma/client/runtime/library").Decimal;
    }) | null>;
}
