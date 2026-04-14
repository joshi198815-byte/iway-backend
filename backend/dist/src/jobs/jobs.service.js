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
exports.JobsService = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const prisma_service_1 = require("../database/prisma/prisma.service");
const runtime_observability_1 = require("../common/observability/runtime-observability");
let JobsService = class JobsService {
    constructor(prisma) {
        this.prisma = prisma;
        this.handlers = new Map();
        this.processing = false;
    }
    registerHandler(name, handler) {
        this.handlers.set(name, handler);
    }
    async onModuleInit() {
        this.pollTimer = setInterval(() => void this.processDueJobs(), 3000);
        await this.requeueStaleJobs();
        queueMicrotask(() => void this.processDueJobs());
    }
    onModuleDestroy() {
        if (this.pollTimer) {
            clearInterval(this.pollTimer);
            this.pollTimer = undefined;
        }
    }
    getScheduledJobs() {
        return [
            'weekly-commission-cutoff-thursday',
            'traveler-auto-block-overdue',
            'traveler-auto-unblock-after-payment',
            'push-dispatch-single',
            'push-dispatch-batch',
            'anti-fraud-scan',
        ];
    }
    async enqueue(params) {
        const job = await this.prisma.backgroundJob.create({
            data: {
                kind: params.name,
                payload: params.payload,
                maxAttempts: Math.max(1, params.maxAttempts ?? 3),
                status: params.initialDelayMs && params.initialDelayMs > 0 ? client_1.BackgroundJobStatus.retrying : client_1.BackgroundJobStatus.queued,
                availableAt: new Date(Date.now() + (params.initialDelayMs ?? 0)),
            },
        });
        queueMicrotask(() => void this.processDueJobs());
        return job;
    }
    async getSnapshot() {
        const [queued, processing, failed, completed, recent] = await Promise.all([
            this.prisma.backgroundJob.count({ where: { status: { in: [client_1.BackgroundJobStatus.queued, client_1.BackgroundJobStatus.retrying] } } }),
            this.prisma.backgroundJob.count({ where: { status: client_1.BackgroundJobStatus.processing } }),
            this.prisma.backgroundJob.count({ where: { status: client_1.BackgroundJobStatus.failed } }),
            this.prisma.backgroundJob.count({ where: { status: client_1.BackgroundJobStatus.completed } }),
            this.prisma.backgroundJob.findMany({ orderBy: { updatedAt: 'desc' }, take: 20 }),
        ]);
        return { queued, processing, failed, completed, recent };
    }
    async requeueStaleJobs() {
        await this.prisma.backgroundJob.updateMany({
            where: { status: client_1.BackgroundJobStatus.processing },
            data: {
                status: client_1.BackgroundJobStatus.retrying,
                availableAt: new Date(),
                lockedAt: null,
            },
        });
    }
    async processDueJobs() {
        if (this.processing)
            return;
        this.processing = true;
        try {
            const jobs = await this.prisma.backgroundJob.findMany({
                where: {
                    status: { in: [client_1.BackgroundJobStatus.queued, client_1.BackgroundJobStatus.retrying] },
                    availableAt: { lte: new Date() },
                },
                orderBy: [{ availableAt: 'asc' }, { createdAt: 'asc' }],
                take: 10,
            });
            for (const job of jobs) {
                await this.processOne(job);
            }
        }
        finally {
            this.processing = false;
        }
    }
    async processOne(job) {
        const handler = this.handlers.get(job.kind);
        if (!handler) {
            return;
        }
        const locked = await this.prisma.backgroundJob.updateMany({
            where: {
                id: job.id,
                status: { in: [client_1.BackgroundJobStatus.queued, client_1.BackgroundJobStatus.retrying] },
            },
            data: {
                status: client_1.BackgroundJobStatus.processing,
                attempts: { increment: 1 },
                startedAt: job.startedAt ?? new Date(),
                lockedAt: new Date(),
                lastError: null,
            },
        });
        if (locked.count === 0) {
            return;
        }
        const current = await this.prisma.backgroundJob.findUnique({ where: { id: job.id } });
        if (!current) {
            return;
        }
        try {
            await handler(current.payload ?? {});
            await this.prisma.backgroundJob.update({
                where: { id: job.id },
                data: {
                    status: client_1.BackgroundJobStatus.completed,
                    completedAt: new Date(),
                    lockedAt: null,
                },
            });
            runtime_observability_1.runtimeObservability.recordBusinessEvent({
                type: 'job_completed',
                entityId: job.id,
                metadata: { name: job.kind, attempts: current.attempts },
            });
        }
        catch (error) {
            const attempts = current.attempts;
            const shouldRetry = attempts < current.maxAttempts;
            const message = error instanceof Error ? error.message : 'unknown_job_error';
            const retryDelayMs = Math.min(30000, 1000 * 2 ** Math.max(0, attempts - 1));
            await this.prisma.backgroundJob.update({
                where: { id: job.id },
                data: {
                    status: shouldRetry ? client_1.BackgroundJobStatus.retrying : client_1.BackgroundJobStatus.failed,
                    availableAt: new Date(Date.now() + (shouldRetry ? retryDelayMs : 0)),
                    lockedAt: null,
                    lastError: message,
                },
            });
            runtime_observability_1.runtimeObservability.recordBusinessEvent({
                type: shouldRetry ? 'job_retry_scheduled' : 'job_failed',
                entityId: job.id,
                metadata: { name: job.kind, attempts, error: message },
            });
        }
    }
};
exports.JobsService = JobsService;
exports.JobsService = JobsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], JobsService);
//# sourceMappingURL=jobs.service.js.map