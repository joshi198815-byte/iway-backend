import { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma/prisma.service';
type JobHandler = (payload: Record<string, unknown>) => Promise<void>;
export declare class JobsService implements OnModuleInit, OnModuleDestroy {
    private readonly prisma;
    private readonly handlers;
    private pollTimer?;
    private processing;
    constructor(prisma: PrismaService);
    registerHandler(name: string, handler: JobHandler): void;
    onModuleInit(): Promise<void>;
    onModuleDestroy(): void;
    getScheduledJobs(): string[];
    enqueue(params: {
        name: string;
        payload?: Record<string, unknown>;
        maxAttempts?: number;
        initialDelayMs?: number;
    }): Promise<{
        status: import(".prisma/client").$Enums.BackgroundJobStatus;
        id: string;
        createdAt: Date;
        updatedAt: Date;
        kind: string;
        payload: Prisma.JsonValue | null;
        attempts: number;
        maxAttempts: number;
        availableAt: Date;
        lastError: string | null;
        lockedAt: Date | null;
        startedAt: Date | null;
        completedAt: Date | null;
    }>;
    getSnapshot(): Promise<{
        queued: number;
        processing: number;
        failed: number;
        completed: number;
        recent: {
            status: import(".prisma/client").$Enums.BackgroundJobStatus;
            id: string;
            createdAt: Date;
            updatedAt: Date;
            kind: string;
            payload: Prisma.JsonValue | null;
            attempts: number;
            maxAttempts: number;
            availableAt: Date;
            lastError: string | null;
            lockedAt: Date | null;
            startedAt: Date | null;
            completedAt: Date | null;
        }[];
    }>;
    private requeueStaleJobs;
    private processDueJobs;
    private processOne;
}
export {};
