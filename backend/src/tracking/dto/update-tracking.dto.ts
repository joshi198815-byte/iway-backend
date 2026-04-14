import { IsNumber, IsOptional, IsString } from 'class-validator';

export class UpdateTrackingDto {
  @IsString()
  shipmentId!: string;

  @IsString()
  travelerId!: string;

  @IsNumber()
  lat!: number;

  @IsNumber()
  lng!: number;

  @IsOptional()
  @IsNumber()
  accuracyM?: number;

  @IsOptional()
  @IsString()
  checkpoint?: string;
}
