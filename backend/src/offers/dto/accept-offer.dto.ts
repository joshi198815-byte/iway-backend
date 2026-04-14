import { IsString } from 'class-validator';

export class AcceptOfferDto {
  @IsString()
  acceptedByCustomerId!: string;
}
