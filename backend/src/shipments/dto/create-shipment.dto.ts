import { IsBoolean, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateShipmentDto {
  @IsOptional()
  @IsString()
  customerId?: string;

  @IsString()
  originCountryCode!: string;

  @IsString()
  destinationCountryCode!: string;

  @IsString()
  packageType!: string;

  @IsOptional()
  @IsString()
  packageCategory?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsNumber()
  @Min(0.01)
  declaredValue!: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  weightLb?: number;

  @IsOptional()
  @IsString()
  senderName?: string;

  @IsOptional()
  @IsString()
  senderPhone?: string;

  @IsOptional()
  @IsString()
  senderAddress?: string;

  @IsOptional()
  @IsString()
  senderStateRegion?: string;

  @IsString()
  receiverName!: string;

  @IsString()
  receiverPhone!: string;

  @IsString()
  receiverAddress!: string;

  @IsOptional()
  @IsNumber()
  pickupLat?: number;

  @IsOptional()
  @IsNumber()
  pickupLng?: number;

  @IsOptional()
  @IsNumber()
  deliveryLat?: number;

  @IsOptional()
  @IsNumber()
  deliveryLng?: number;

  @IsBoolean()
  insuranceEnabled!: boolean;
}
