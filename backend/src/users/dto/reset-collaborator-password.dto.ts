import { IsOptional, IsString, MinLength } from 'class-validator';

export class ResetCollaboratorPasswordDto {
  @IsOptional()
  @IsString()
  @MinLength(8)
  password?: string;
}
