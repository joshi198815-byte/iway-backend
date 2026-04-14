import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { HealthModule } from '../health/health.module';
import { JobsModule } from '../jobs/jobs.module';

@Module({
  imports: [HealthModule, JobsModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
