import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { StorageService } from './storage.service';
import { UploadBase64Dto } from './dto/upload-base64.dto';

@UseGuards(JwtAuthGuard)
@Controller('storage')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Get('blueprint')
  getBlueprint() {
    return this.storageService.getUploadBlueprint();
  }

  @Post('upload-base64')
  uploadBase64(@Body() body: UploadBase64Dto, @Req() req: any) {
    if (body.bucket == 'transfer-proofs' && !['traveler', 'admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('No tienes permiso para subir archivos a este bucket.');
    }

    return this.storageService.uploadBase64(body, req.user.sub);
  }

  @Get('file/:bucket/:ownerId/:fileName')
  async getProtectedFile(
    @Param('bucket') bucket: string,
    @Param('ownerId') ownerId: string,
    @Param('fileName') fileName: string,
    @Req() req: any,
    @Res() res: any,
  ) {
    const absolutePath = await this.storageService.resolveProtectedFile({
      bucket,
      ownerId,
      fileName,
      requesterId: req.user.sub,
      requesterRole: req.user.role,
    });

    return res.sendFile(absolutePath);
  }

  @Get('file-preview/:bucket/:ownerId/:fileName')
  async getProtectedFilePreview(
    @Param('bucket') bucket: string,
    @Param('ownerId') ownerId: string,
    @Param('fileName') fileName: string,
    @Req() req: any,
  ) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede previsualizar archivos protegidos en JSON.');
    }

    return this.storageService.getProtectedFilePreview({
      bucket,
      ownerId,
      fileName,
      requesterId: req.user.sub,
      requesterRole: req.user.role,
    });
  }
}
