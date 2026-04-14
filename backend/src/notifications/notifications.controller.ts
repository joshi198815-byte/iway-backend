import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';

@UseGuards(JwtAuthGuard)

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string, @Req() req: any) {
    if (req.user.sub !== userId && !['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('No puedes ver notificaciones de otro usuario.');
    }

    return this.notificationsService.findByUser(userId);
  }

  @Post()
  create(
    @Body()
    body: { userId: string; title: string; body: string; type?: string; shipmentId?: string },
    @Req() req: any,
  ) {
    if (!['admin', 'support'].includes(req.user.role)) {
      throw new ForbiddenException('Solo admin o soporte puede crear notificaciones manuales.');
    }
    return this.notificationsService.create(
      body.userId,
      body.title,
      body.body,
      body.type,
      body.shipmentId,
    );
  }

  @Post('device-token')
  registerDeviceToken(@Body() body: RegisterDeviceTokenDto, @Req() req: any) {
    return this.notificationsService.registerDeviceToken(req.user.sub, body);
  }

  @Post('device-token/deactivate')
  deactivateDeviceToken(@Body() body: { token: string }, @Req() req: any) {
    return this.notificationsService.deactivateDeviceToken(req.user.sub, body.token);
  }

  @Post(':id/read')
  markRead(@Param('id') id: string, @Req() req: any) {
    return this.notificationsService.markRead(id, req.user);
  }
}
