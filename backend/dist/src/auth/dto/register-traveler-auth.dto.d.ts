import { RegisterTravelerDto } from '../../travelers/dto/register-traveler.dto';
export declare class RegisterTravelerAuthDto extends RegisterTravelerDto {
    fullName: string;
    email: string;
    phone: string;
    password: string;
    countryCode?: string;
    stateRegion?: string;
    city?: string;
    address?: string;
    documentUrl?: string;
    selfieUrl?: string;
    documentBase64?: string;
    selfieBase64?: string;
}
