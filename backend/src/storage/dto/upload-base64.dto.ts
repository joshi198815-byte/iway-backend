import { IsIn, IsOptional, IsString } from 'class-validator';

export class UploadBase64Dto {
  @IsString()
  @IsIn(['documents', 'shipment-images', 'transfer-proofs'])
  bucket!: string;

  @IsString()
  base64!: string;

  @IsOptional()
  @IsString()
  fileName?: string;
}
