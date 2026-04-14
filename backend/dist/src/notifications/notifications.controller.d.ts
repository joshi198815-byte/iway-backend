import { NotificationsService } from './notifications.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
export declare class NotificationsController {
    private readonly notificationsService;
    constructor(notificationsService: NotificationsService);
    findByUser(userId: string, req: any): Promise<{
        id: string;
        createdAt: Date;
        userId: string;
        title: string;
        body: string;
        type: string;
        shipmentId: string | null;
        readAt: Date | null;
    }[]>;
    create(body: {
        userId: string;
        title: string;
        body: string;
        type?: string;
        shipmentId?: string;
    }, req: any): Promise<{
        id: string;
        createdAt: Date;
        userId: string;
        title: string;
        body: string;
        type: string;
        shipmentId: string | null;
        readAt: Date | null;
    }>;
    registerDeviceToken(body: RegisterDeviceTokenDto, req: any): Promise<{
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
    deactivateDeviceToken(body: {
        token: string;
    }, req: any): Promise<import(".prisma/client").Prisma.BatchPayload>;
    markRead(id: string, req: any): Promise<{
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
