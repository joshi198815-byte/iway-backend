import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  countryCode?: string;

  @IsOptional()
  @IsString()
  stateRegion?: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  selfieUrl?: string;

  @IsOptional()
  @IsBoolean()
  phoneVerified?: boolean;
}
