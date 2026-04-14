export declare class AuditService {
    log(action: string, entityType: string, entityId?: string): {
        action: string;
        entityType: string;
        entityId: string | undefined;
    };
}
