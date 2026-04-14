import { RatingsService } from './ratings.service';
import { CreateRatingDto } from './dto/create-rating.dto';
export declare class RatingsController {
    private readonly ratingsService;
    constructor(ratingsService: RatingsService);
    getBlueprint(): {
        flow: string;
    };
    findByUser(userId: string, req: any): Promise<{
        id: string;
        createdAt: Date;
        shipmentId: string;
        fromUserId: string;
        toUserId: string;
        stars: number;
        comment: string | null;
    }[]>;
    create(body: CreateRatingDto, req: any): Promise<{
        id: string;
        createdAt: Date;
        shipmentId: string;
        fromUserId: string;
        toUserId: string;
        stars: number;
        comment: string | null;
    }>;
}
