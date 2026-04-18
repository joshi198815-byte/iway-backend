import { Module } from '@nestjs/common';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { AntiFraudModule } from '../anti-fraud/anti-fraud.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [AntiFraudModule, NotificationsModule],
  controllers: [ChatController],
  providers: [ChatService],
  exports: [ChatService],
})
export class ChatModule {}
