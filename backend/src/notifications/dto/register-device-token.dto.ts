import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceTokenDto {
  @IsString()
  @MinLength(8)
  token!: string;

  @IsString()
  @IsIn(['android', 'ios', 'web'])
  platform!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceLabel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(180)
  installationId?: string;
}
