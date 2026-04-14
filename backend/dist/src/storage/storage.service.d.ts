import { PrismaService } from '../database/prisma/prisma.service';
import { UploadBase64Dto } from './dto/upload-base64.dto';
export declare class StorageService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    private readonly buckets;
    getUploadBlueprint(): {
        buckets: readonly ["documents", "shipment-images", "transfer-proofs"];
        mode: string;
        baseUrl: string;
        uploadsDir: string;
        retentionPolicy: {
            documents: string;
            shipmentImages: string;
            transferProofs: string;
        };
    };
    uploadBase64(payload: UploadBase64Dto, ownerId: string): Promise<{
        id: string;
        bucket: string;
        ownerId: string;
        fileName: string;
        contentType: string;
        sizeBytes: number;
        path: string;
        url: string;
        protectedUrl: string;
        publicUrl: string;
    }>;
    attachFilesToEntity(params: {
        ownerId: string;
        urls: string[];
        linkedEntityType: string;
        linkedEntityId: string;
        purpose: string;
    }): Promise<{
        count: number;
    }>;
    resolveProtectedFile(params: {
        bucket: string;
        ownerId: string;
        fileName: string;
        requesterId: string;
        requesterRole?: string;
    }): Promise<string>;
}
