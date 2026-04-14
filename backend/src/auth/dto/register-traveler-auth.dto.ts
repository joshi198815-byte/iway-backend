import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { RegisterTravelerDto } from '../../travelers/dto/register-traveler.dto';

export class RegisterTravelerAuthDto extends RegisterTravelerDto {
  @IsString()
  fullName!: string;

  @IsEmail()
  email!: string;

  @IsString()
  phone!: string;

  @IsString()
  @MinLength(6)
  password!: string;

  @IsOptional()
  @IsString()
  countryCode?: string;

  @IsOptional()
  @IsString()
  stateRegion?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  documentUrl?: string;

  @IsOptional()
  @IsString()
  selfieUrl?: string;

  @IsOptional()
  @IsString()
  documentBase64?: string;

  @IsOptional()
  @IsString()
  selfieBase64?: string;
}
