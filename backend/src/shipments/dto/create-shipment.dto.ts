import { IsBoolean, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateShipmentDto {
  @IsString()
  customerId!: string;

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

  @IsString()
  receiverName!: string;

  @IsString()
  receiverPhone!: string;

  @IsString()
  receiverAddress!: string;

  @IsOptional()
  @IsNumber()
  deliveryLat?: number;

  @IsOptional()
  @IsNumber()
  deliveryLng?: number;

  @IsBoolean()
  insuranceEnabled!: boolean;
}
