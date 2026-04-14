import { IsIn, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateLedgerAdjustmentDto {
  @IsIn(['debit', 'credit'])
  direction!: 'debit' | 'credit';

  @IsNumber()
  @Min(0.01)
  amount!: number;

  @IsString()
  @IsNotEmpty()
  description!: string;

  @IsOptional()
  @IsString()
  weeklySettlementId?: string;
}
