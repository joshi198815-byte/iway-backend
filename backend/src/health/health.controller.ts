import { Controller, Get } from '@nestjs/common';
import { runtimeObservability } from '../common/observability/runtime-observability';
import { HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  async getHealth() {
    const snapshot = await this.healthService.getHealthSnapshot();
    return {
      ...snapshot,
      observability: runtimeObservability.getSnapshot(),
    };
  }

  @Get('live')
  getLiveness() {
    return {
      ok: true,
      live: true,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('ready')
  async getReadiness() {
    const db = await this.healthService.getDatabaseHealth();
    return {
      ok: db.ok,
      ready: db.ok,
      env: process.env.NODE_ENV ?? 'development',
      uptimeMs: runtimeObservability.getSnapshot().uptimeMs,
      database: db,
      timestamp: new Date().toISOString(),
    };
  }

  @Get('metrics')
  async getMetrics() {
    return {
      service: 'iway-backend',
      generatedAt: new Date().toISOString(),
      business: await this.healthService.getBusinessMetrics(),
      runtime: runtimeObservability.getSnapshot(),
    };
  }
}
