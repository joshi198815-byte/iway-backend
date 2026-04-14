"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AdminService = void 0;
const common_1 = require("@nestjs/common");
const runtime_observability_1 = require("../common/observability/runtime-observability");
const health_service_1 = require("../health/health.service");
const jobs_service_1 = require("../jobs/jobs.service");
let AdminService = class AdminService {
    constructor(healthService, jobsService) {
        this.healthService = healthService;
        this.jobsService = jobsService;
    }
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
            runtime: runtime_observability_1.runtimeObservability.getSnapshot(),
            jobs,
            alerting: {
                webhookConfigured: Boolean(process.env.OBSERVABILITY_ALERT_WEBHOOK_URL),
                cooldownMs: Number(process.env.OBSERVABILITY_ALERT_COOLDOWN_MS ?? 120000),
            },
        };
    }
};
exports.AdminService = AdminService;
exports.AdminService = AdminService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [health_service_1.HealthService,
        jobs_service_1.JobsService])
], AdminService);
//# sourceMappingURL=admin.service.js.map