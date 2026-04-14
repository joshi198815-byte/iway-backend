import { PrismaService } from '../database/prisma/prisma.service';
export declare class HealthService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    getHealthSnapshot(): Promise<{
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
    getDatabaseHealth(): Promise<{
        ok: boolean;
        latencyMs: number;
        message?: undefined;
    } | {
        ok: boolean;
        latencyMs: number;
        message: string;
    }>;
    getBusinessMetrics(): Promise<{
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
    }>;
}
