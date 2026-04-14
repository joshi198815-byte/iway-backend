import { IsIn, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateManualFlagDto {
  @IsString()
  @MaxLength(120)
  flagType!: string;

  @IsString()
  @IsIn(['low', 'medium', 'high'])
  severity!: 'low' | 'medium' | 'high';

  @IsOptional()
  @IsObject()
  details?: Record<string, unknown>;
}
