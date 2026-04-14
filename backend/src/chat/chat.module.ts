import { Module } from '@nestjs/common';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { AntiFraudModule } from '../anti-fraud/anti-fraud.module';

@Module({
  imports: [AntiFraudModule],
  controllers: [ChatController],
  providers: [ChatService],
  exports: [ChatService],
})
export class ChatModule {}
