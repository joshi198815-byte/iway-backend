import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthModule } from './health/health.module';
import { DatabaseModule } from './database/database.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { TravelersModule } from './travelers/travelers.module';
import { GeoModule } from './geo/geo.module';
import { ShipmentsModule } from './shipments/shipments.module';
import { OffersModule } from './offers/offers.module';
import { ChatModule } from './chat/chat.module';
import { TrackingModule } from './tracking/tracking.module';
import { RatingsModule } from './ratings/ratings.module';
import { NotificationsModule } from './notifications/notifications.module';
import { CommissionsModule } from './commissions/commissions.module';
import { TransfersModule } from './transfers/transfers.module';
import { AntiFraudModule } from './anti-fraud/anti-fraud.module';
import { AdminModule } from './admin/admin.module';
import { AuditModule } from './audit/audit.module';
import { StorageModule } from './storage/storage.module';
import { JobsModule } from './jobs/jobs.module';
import { RealtimeModule } from './realtime/realtime.module';
import { DisputesModule } from './disputes/disputes.module';
import { FinanceModule } from './finance/finance.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    HealthModule,
    DatabaseModule,
    AuthModule,
    UsersModule,
    TravelersModule,
    GeoModule,
    ShipmentsModule,
    OffersModule,
    ChatModule,
    TrackingModule,
    RatingsModule,
    NotificationsModule,
    CommissionsModule,
    TransfersModule,
    AntiFraudModule,
    AdminModule,
    AuditModule,
    StorageModule,
    JobsModule,
    RealtimeModule,
    DisputesModule,
    FinanceModule,
  ],
})
export class AppModule {}
