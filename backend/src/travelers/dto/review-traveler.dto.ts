import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class ReviewTravelerDto {
  @IsString()
  @IsIn(['approve', 'reject', 'block'])
  action!: 'approve' | 'reject' | 'block';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
