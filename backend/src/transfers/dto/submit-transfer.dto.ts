import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class SubmitTransferDto {
  @IsNumber()
  @Min(0.01)
  amount!: number;

  @IsOptional()
  @IsString()
  weeklySettlementId?: string;

  @IsOptional()
  @IsString()
  bankReference?: string;

  @IsOptional()
  @IsString()
  proofUrl?: string;
}
