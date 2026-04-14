import { TravelerType } from '@prisma/client';
export declare class CreateTravelerProfileDto {
    userId: string;
    travelerType: TravelerType;
    documentNumber: string;
    documentUrl?: string;
    selfieUrl?: string;
    detectedCountryCode?: string;
}
