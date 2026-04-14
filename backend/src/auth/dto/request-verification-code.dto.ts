import { IsIn, IsString } from 'class-validator';

export class RequestVerificationCodeDto {
  @IsString()
  @IsIn(['phone', 'email'])
  channel!: 'phone' | 'email';
}
