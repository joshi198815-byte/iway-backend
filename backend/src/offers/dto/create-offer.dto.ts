import { IsNumber, IsString, Min } from 'class-validator';

export class CreateOfferDto {
  @IsString()
  shipmentId!: string;

  @IsString()
  travelerId!: string;

  @IsNumber()
  @Min(0.01)
  price!: number;
}
