import { StorageService } from './storage.service';
import { UploadBase64Dto } from './dto/upload-base64.dto';
export declare class StorageController {
    private readonly storageService;
    constructor(storageService: StorageService);
    getBlueprint(): {
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
    uploadBase64(body: UploadBase64Dto, req: any): Promise<{
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
    getProtectedFile(bucket: string, ownerId: string, fileName: string, req: any, res: any): Promise<any>;
}
