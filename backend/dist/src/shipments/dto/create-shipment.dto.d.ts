export declare class CreateShipmentDto {
    customerId: string;
    originCountryCode: string;
    destinationCountryCode: string;
    packageType: string;
    packageCategory?: string;
    description?: string;
    declaredValue: number;
    weightLb?: number;
    receiverName: string;
    receiverPhone: string;
    receiverAddress: string;
    pickupLat?: number;
    pickupLng?: number;
    deliveryLat?: number;
    deliveryLng?: number;
    insuranceEnabled: boolean;
    imageUrls?: string[];
}
