import { IsOptional, IsString } from 'class-validator';

export class RunWeeklyCutoffDto {
  @IsOptional()
  @IsString()
  runDateIso?: string;
}
