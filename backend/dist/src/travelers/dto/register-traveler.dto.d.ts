import { TravelerType } from '../../common/constants/traveler-types';
export declare class RegisterTravelerDto {
    travelerType: TravelerType;
    documentNumber: string;
    detectedCountryCode?: string;
}
