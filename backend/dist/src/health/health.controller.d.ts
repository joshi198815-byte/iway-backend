import { HealthService } from './health.service';
export declare class HealthController {
    private readonly healthService;
    constructor(healthService: HealthService);
    getHealth(): Promise<{
        observability: {
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
        ok: boolean;
        service: string;
        env: string;
        version: string;
        timestamp: string;
        dependencies: {
            database: {
                ok: boolean;
                latencyMs: number;
                message?: undefined;
            } | {
                ok: boolean;
                latencyMs: number;
                message: string;
            };
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
    }>;
    getLiveness(): {
        ok: boolean;
        live: boolean;
        timestamp: string;
    };
    getReadiness(): Promise<{
        ok: boolean;
        ready: boolean;
        env: string;
        uptimeMs: number;
        database: {
            ok: boolean;
            latencyMs: number;
            message?: undefined;
        } | {
            ok: boolean;
            latencyMs: number;
            message: string;
        };
        timestamp: string;
    }>;
    getMetrics(): Promise<{
        service: string;
        generatedAt: string;
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
    }>;
}
