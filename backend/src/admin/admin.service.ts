import { Injectable } from '@nestjs/common';
import { runtimeObservability } from '../common/observability/runtime-observability';
import { HealthService } from '../health/health.service';
import { JobsService } from '../jobs/jobs.service';

@Injectable()
export class AdminService {
  constructor(
    private readonly healthService: HealthService,
    private readonly jobsService: JobsService,
  ) {}

  getDashboardBlueprint() {
    return {
      panels: ['travelers', 'shipments', 'settlements', 'transfers', 'fraud-flags', 'disputes', 'observability'],
    };
  }

  async getObservabilityDashboard() {
    const [health, database, jobs] = await Promise.all([
      this.healthService.getBusinessMetrics(),
      this.healthService.getDatabaseHealth(),
      this.jobsService.getSnapshot(),
    ]);

    return {
      generatedAt: new Date().toISOString(),
      database,
      business: health,
      runtime: runtimeObservability.getSnapshot(),
      jobs,
      alerting: {
        webhookConfigured: Boolean(process.env.OBSERVABILITY_ALERT_WEBHOOK_URL),
        cooldownMs: Number(process.env.OBSERVABILITY_ALERT_COOLDOWN_MS ?? 120000),
      },
    };
  }
}
