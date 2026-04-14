import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { UsersModule } from '../users/users.module';
import { TravelersModule } from '../travelers/travelers.module';
import { GeoModule } from '../geo/geo.module';
import { StorageModule } from '../storage/storage.module';
import { AntiFraudModule } from '../anti-fraud/anti-fraud.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { JobsModule } from '../jobs/jobs.module';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET ?? 'change-me',
      signOptions: { expiresIn: '7d' },
    }),
    UsersModule,
    TravelersModule,
    GeoModule,
    StorageModule,
    AntiFraudModule,
    NotificationsModule,
    JobsModule,
  ],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [AuthService],
})
export class AuthModule {}
