import { PrismaService } from '../database/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateRatingDto } from './dto/create-rating.dto';
export declare class RatingsService {
    private readonly prisma;
    private readonly notificationsService;
    constructor(prisma: PrismaService, notificationsService: NotificationsService);
    getBlueprint(): {
        flow: string;
    };
    findByUser(userId: string, requester: {
        sub: string;
        role: string;
    }): Promise<{
        id: string;
        createdAt: Date;
        shipmentId: string;
        fromUserId: string;
        toUserId: string;
        stars: number;
        comment: string | null;
    }[]>;
    create(payload: CreateRatingDto): Promise<{
        id: string;
        createdAt: Date;
        shipmentId: string;
        fromUserId: string;
        toUserId: string;
        stars: number;
        comment: string | null;
    }>;
}
