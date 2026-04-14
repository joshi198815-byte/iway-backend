import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { BackgroundJob, BackgroundJobStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
import { runtimeObservability } from '../common/observability/runtime-observability';

type JobHandler = (payload: Record<string, unknown>) => Promise<void>;

@Injectable()
export class JobsService implements OnModuleInit, OnModuleDestroy {
  private readonly handlers = new Map<string, JobHandler>();
  private pollTimer?: NodeJS.Timeout;
  private processing = false;

  constructor(private readonly prisma: PrismaService) {}

  registerHandler(name: string, handler: JobHandler) {
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

  async enqueue(params: {
    name: string;
    payload?: Record<string, unknown>;
    maxAttempts?: number;
    initialDelayMs?: number;
  }) {
    const job = await this.prisma.backgroundJob.create({
      data: {
        kind: params.name,
        payload: params.payload as Prisma.InputJsonValue | undefined,
        maxAttempts: Math.max(1, params.maxAttempts ?? 3),
        status: params.initialDelayMs && params.initialDelayMs > 0 ? BackgroundJobStatus.retrying : BackgroundJobStatus.queued,
        availableAt: new Date(Date.now() + (params.initialDelayMs ?? 0)),
      },
    });

    queueMicrotask(() => void this.processDueJobs());
    return job;
  }

  async getSnapshot() {
    const [queued, processing, failed, completed, recent] = await Promise.all([
      this.prisma.backgroundJob.count({ where: { status: { in: [BackgroundJobStatus.queued, BackgroundJobStatus.retrying] } } }),
      this.prisma.backgroundJob.count({ where: { status: BackgroundJobStatus.processing } }),
      this.prisma.backgroundJob.count({ where: { status: BackgroundJobStatus.failed } }),
      this.prisma.backgroundJob.count({ where: { status: BackgroundJobStatus.completed } }),
      this.prisma.backgroundJob.findMany({ orderBy: { updatedAt: 'desc' }, take: 20 }),
    ]);

    return { queued, processing, failed, completed, recent };
  }

  private async requeueStaleJobs() {
    await this.prisma.backgroundJob.updateMany({
      where: { status: BackgroundJobStatus.processing },
      data: {
        status: BackgroundJobStatus.retrying,
        availableAt: new Date(),
        lockedAt: null,
      },
    });
  }

  private async processDueJobs() {
    if (this.processing) return;
    this.processing = true;

    try {
      const jobs = await this.prisma.backgroundJob.findMany({
        where: {
          status: { in: [BackgroundJobStatus.queued, BackgroundJobStatus.retrying] },
          availableAt: { lte: new Date() },
        },
        orderBy: [{ availableAt: 'asc' }, { createdAt: 'asc' }],
        take: 10,
      });

      for (const job of jobs) {
        await this.processOne(job);
      }
    } finally {
      this.processing = false;
    }
  }

  private async processOne(job: BackgroundJob) {
    const handler = this.handlers.get(job.kind);
    if (!handler) {
      return;
    }

    const locked = await this.prisma.backgroundJob.updateMany({
      where: {
        id: job.id,
        status: { in: [BackgroundJobStatus.queued, BackgroundJobStatus.retrying] },
      },
      data: {
        status: BackgroundJobStatus.processing,
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
      await handler((current.payload as Record<string, unknown> | null) ?? {});
      await this.prisma.backgroundJob.update({
        where: { id: job.id },
        data: {
          status: BackgroundJobStatus.completed,
          completedAt: new Date(),
          lockedAt: null,
        },
      });

      runtimeObservability.recordBusinessEvent({
        type: 'job_completed',
        entityId: job.id,
        metadata: { name: job.kind, attempts: current.attempts },
      });
    } catch (error) {
      const attempts = current.attempts;
      const shouldRetry = attempts < current.maxAttempts;
      const message = error instanceof Error ? error.message : 'unknown_job_error';
      const retryDelayMs = Math.min(30000, 1000 * 2 ** Math.max(0, attempts - 1));

      await this.prisma.backgroundJob.update({
        where: { id: job.id },
        data: {
          status: shouldRetry ? BackgroundJobStatus.retrying : BackgroundJobStatus.failed,
          availableAt: new Date(Date.now() + (shouldRetry ? retryDelayMs : 0)),
          lockedAt: null,
          lastError: message,
        },
      });

      runtimeObservability.recordBusinessEvent({
        type: shouldRetry ? 'job_retry_scheduled' : 'job_failed',
        entityId: job.id,
        metadata: { name: job.kind, attempts, error: message },
      });
    }
  }
}
