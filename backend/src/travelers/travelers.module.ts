import { Module } from '@nestjs/common';
import { TravelersController } from './travelers.controller';
import { NotificationsModule } from '../notifications/notifications.module';
import { TravelersService } from './travelers.service';

@Module({
  imports: [NotificationsModule],
  controllers: [TravelersController],
  providers: [TravelersService],
  exports: [TravelersService],
})
export class TravelersModule {}
