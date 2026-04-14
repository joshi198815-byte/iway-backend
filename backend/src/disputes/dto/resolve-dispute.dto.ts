import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class ResolveDisputeDto {
  @IsString()
  @IsIn(['resolved', 'rejected', 'escalated'])
  status!: 'resolved' | 'rejected' | 'escalated';

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  resolution?: string;
}
