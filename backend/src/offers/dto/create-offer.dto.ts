import { IsNumber, IsString, Min } from 'class-validator';

export class CreateOfferDto {
  @IsString()
  shipmentId!: string;

  @IsNumber()
  @Min(0.01)
  price!: number;
}
