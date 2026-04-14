import { OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { JobsService } from '../jobs/jobs.service';
export declare class NotificationsService implements OnModuleInit {
    private readonly prisma;
    private readonly realtimeGateway;
    private readonly jobsService;
    constructor(prisma: PrismaService, realtimeGateway: RealtimeGateway, jobsService: JobsService);
    onModuleInit(): void;
    private base64UrlEncode;
    private firebaseConfigured;
    private getFirebaseAccessToken;
    private sendFirebasePushToToken;
    findByUser(userId: string): Promise<{
        id: string;
        createdAt: Date;
        userId: string;
        title: string;
        body: string;
        type: string;
        shipmentId: string | null;
        readAt: Date | null;
    }[]>;
    create(userId: string, title: string, body: string, type?: string, shipmentId?: string): Promise<{
        id: string;
        createdAt: Date;
        userId: string;
        title: string;
        body: string;
        type: string;
        shipmentId: string | null;
        readAt: Date | null;
    }>;
    createMany(userIds: string[], title: string, body: string, type?: string, shipmentId?: string): Promise<import(".prisma/client").Prisma.BatchPayload>;
    markRead(id: string, requester: {
        sub: string;
        role: string;
    }): Promise<{
        id: string;
        createdAt: Date;
        userId: string;
        title: string;
        body: string;
        type: string;
        shipmentId: string | null;
        readAt: Date | null;
    }>;
    sendPushMany(userIds: string[], title: string, body: string, type?: string, shipmentId?: string): Promise<{
        queued: boolean;
        providerConfigured: boolean;
        userCount: number;
        deviceCount: number;
        sentCount: number;
        jobId?: undefined;
    } | {
        queued: boolean;
        providerConfigured: boolean;
        userCount: number;
        deviceCount: number;
        sentCount: number;
        jobId: string | null;
    }>;
    registerDeviceToken(userId: string, payload: RegisterDeviceTokenDto): Promise<{
        active: boolean;
        id: string;
        createdAt: Date;
        token: string;
        updatedAt: Date;
        userId: string;
        platform: string;
        deviceLabel: string | null;
        installationId: string | null;
        fingerprint: string | null;
        trustScore: number;
        suspicious: boolean;
        trustedAt: Date | null;
        lastSeenAt: Date;
    }>;
    deactivateDeviceToken(userId: string, token: string): Promise<import(".prisma/client").Prisma.BatchPayload>;
    sendPush(userId: string, title: string, body: string, type?: string, shipmentId?: string): Promise<{
        queued: boolean;
        providerConfigured: boolean;
        deviceCount: number;
        sentCount: number;
        jobId: string | null;
        devices: {
            id: string;
            platform: string;
            sent: boolean;
        }[];
        id: string;
        createdAt: Date;
        userId: string;
        title: string;
        body: string;
        type: string;
        shipmentId: string | null;
        readAt: Date | null;
    }>;
}
