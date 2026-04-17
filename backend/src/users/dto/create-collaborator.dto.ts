import { UserRole } from '@prisma/client';
import { IsEmail, IsEnum, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateCollaboratorDto {
  @IsString()
  fullName!: string;

  @IsEmail()
  email!: string;

  @IsString()
  phone!: string;

  @IsEnum(UserRole)
  role!: UserRole;

  @IsOptional()
  @IsString()
  @MinLength(8)
  password?: string;

  @IsOptional()
  @IsString()
  countryCode?: string;

  @IsOptional()
  @IsString()
  detectedCountryCode?: string;

  @IsOptional()
  @IsString()
  stateRegion?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  address?: string;
}
