import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class RegisterCommissionPaymentDto {
  @IsString()
  travelerId!: string;

  @IsNumber()
  @Min(0.01)
  transferredAmount!: number;

  @IsOptional()
  @IsString()
  bankReference?: string;
}
