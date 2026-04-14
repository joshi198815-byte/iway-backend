import { IsOptional, IsString } from 'class-validator';

export class DetectCountryDto {
  @IsOptional()
  @IsString()
  countryCode?: string;

  @IsOptional()
  @IsString()
  ipAddress?: string;
}
