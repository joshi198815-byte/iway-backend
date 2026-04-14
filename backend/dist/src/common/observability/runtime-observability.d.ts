type RequestMetricInput = {
    method: string;
    path: string;
    statusCode: number;
    durationMs: number;
};
type ErrorMetricInput = {
    method?: string;
    path?: string;
    statusCode: number;
    requestId?: string;
    message: string;
};
declare class RuntimeObservabilityStore {
    private readonly startedAt;
    private totalRequests;
    private totalErrors;
    private totalDurationMs;
    private slowestRequestMs;
    private readonly routes;
    private readonly recentErrors;
    private readonly recentBusinessEvents;
    recordRequest(input: RequestMetricInput): void;
    recordError(input: ErrorMetricInput): void;
    recordBusinessEvent(input: {
        type: string;
        entityId?: string;
        actorId?: string;
        shipmentId?: string;
        metadata?: Record<string, unknown>;
    }): void;
    getSnapshot(): {
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
}
export declare const runtimeObservability: RuntimeObservabilityStore;
export {};
