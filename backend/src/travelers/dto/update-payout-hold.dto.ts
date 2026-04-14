import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdatePayoutHoldDto {
  @IsBoolean()
  enabled!: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
