import { IsIn, IsString, Length } from 'class-validator';

export class VerifyContactCodeDto {
  @IsString()
  @IsIn(['phone', 'email'])
  channel!: 'phone' | 'email';

  @IsString()
  @Length(6, 6)
  code!: string;
}
