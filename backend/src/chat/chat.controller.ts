import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { ChatService } from './chat.service';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)

@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get(':chatId/messages')
  findMessages(@Param('chatId') chatId: string, @Req() req: any) {
    return this.chatService.findMessages(chatId, req.user.sub);
  }

  @Post('shipment/:shipmentId')
  getOrCreateByShipment(@Param('shipmentId') shipmentId: string, @Req() req: any) {
    return this.chatService.getOrCreateByShipment(shipmentId, req.user.sub);
  }

  @Post('messages')
  sendMessage(@Body() body: SendMessageDto, @Req() req: any) {
    return this.chatService.sendMessage({
      ...body,
      senderId: req.user.sub,
    });
  }
}
