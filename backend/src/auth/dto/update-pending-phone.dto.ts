import { IsString, Length, Matches } from 'class-validator';

export class UpdatePendingPhoneDto {
  @IsString()
  @Length(8, 24)
  @Matches(/^[+0-9()\-\s]+$/, { message: 'Número de teléfono inválido.' })
  phone!: string;
}
