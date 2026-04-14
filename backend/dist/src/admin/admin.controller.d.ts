import { AdminService } from './admin.service';
export declare class AdminController {
    private readonly adminService;
    constructor(adminService: AdminService);
    getDashboardBlueprint(req: any): {
        panels: string[];
    };
    getObservabilityDashboard(req: any): Promise<{
        generatedAt: string;
        database: {
            ok: boolean;
            latencyMs: number;
            message?: undefined;
        } | {
            ok: boolean;
            latencyMs: number;
            message: string;
        };
        business: {
            users: {
                total: number;
                customers: number;
                travelers: number;
                admins: number;
                blocked: number;
                pendingVerification: number;
            };
            travelers: {
                pending: number;
                verified: number;
                blocked: number;
                rejected: number;
            };
            shipments: {
                published: number;
                assigned: number;
                delivered: number;
                disputed: number;
            };
            offers: {
                pending: number;
                accepted: number;
            };
            transfers: {
                submitted: number;
                approved: number;
                rejected: number;
            };
            commissions: {
                actionable: number;
                overdue: number;
                paid: number;
            };
        };
        runtime: {
            uptimeMs: number;
            totalRequests: number;
            totalErrors: number;
            avgDurationMs: number;
            slowestRequestMs: number;
            hotRoutes: {
                method: string;
                path: string;
                count: number;
                errorCount: number;
                avgDurationMs: number;
                lastStatusCode: number;
                lastSeenAt: string;
            }[];
            recentErrors: {
                at: string;
                requestId?: string;
                method?: string;
                path?: string;
                statusCode: number;
                message: string;
            }[];
            recentBusinessEvents: {
                at: string;
                type: string;
                entityId?: string;
                actorId?: string;
                shipmentId?: string;
                metadata?: Record<string, unknown>;
            }[];
            memory: {
                rssMb: number;
                heapUsedMb: number;
            };
        };
        jobs: {
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
                payload: import("@prisma/client/runtime/library").JsonValue | null;
                attempts: number;
                maxAttempts: number;
                availableAt: Date;
                lastError: string | null;
                lockedAt: Date | null;
                startedAt: Date | null;
                completedAt: Date | null;
            }[];
        };
        alerting: {
            webhookConfigured: boolean;
            cooldownMs: number;
        };
    }>;
}
