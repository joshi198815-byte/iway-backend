import { IsEnum, IsOptional, IsString } from 'class-validator';
import { TravelerType } from '../../common/constants/traveler-types';

export class RegisterTravelerDto {
  @IsEnum(TravelerType)
  travelerType!: TravelerType;

  @IsString()
  documentNumber!: string;

  @IsOptional()
  @IsString()
  detectedCountryCode?: string;
}
