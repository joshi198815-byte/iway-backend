import { UserRole } from '@prisma/client';
export declare class CreateUserDto {
    role: UserRole;
    fullName: string;
    email: string;
    phone: string;
    passwordHash: string;
    countryCode?: string;
    detectedCountryCode?: string;
    stateRegion?: string;
    city?: string;
    address?: string;
}
