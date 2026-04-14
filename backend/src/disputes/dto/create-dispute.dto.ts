import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateDisputeDto {
  @IsString()
  @MinLength(6)
  shipmentId!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(500)
  reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  context?: string;
}
