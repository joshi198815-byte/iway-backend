import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class UpdatePricingSettingsDto {
  @IsNumber()
  @Min(0)
  commissionPerLb!: number;

  @IsNumber()
  @Min(0)
  groundCommissionPercent!: number;

  @IsOptional()
  @IsString()
  actorId?: string;
}
