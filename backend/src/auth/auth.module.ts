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

const jwtSecret = process.env.JWT_SECRET?.trim();

if (!jwtSecret) {
  throw new Error('JWT_SECRET is required');
}

@Module({
  imports: [
    JwtModule.register({
      secret: jwtSecret,
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
