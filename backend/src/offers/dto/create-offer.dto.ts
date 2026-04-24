import { IsNumber, IsString, Max, Min } from 'class-validator';

export class CreateOfferDto {
  @IsString()
  shipmentId!: string;

  @IsNumber()
  @Min(0.01)
  @Max(9999.99)
  price!: number;
}
