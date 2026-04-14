"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runtimeObservability = void 0;
class RuntimeObservabilityStore {
    constructor() {
        this.startedAt = Date.now();
        this.totalRequests = 0;
        this.totalErrors = 0;
        this.totalDurationMs = 0;
        this.slowestRequestMs = 0;
        this.routes = new Map();
        this.recentErrors = [];
        this.recentBusinessEvents = [];
    }
    recordRequest(input) {
        const key = `${input.method} ${input.path}`;
        const existing = this.routes.get(key) ?? {
            key,
            method: input.method,
            path: input.path,
            count: 0,
            errorCount: 0,
            totalDurationMs: 0,
            lastStatusCode: input.statusCode,
            lastSeenAt: new Date().toISOString(),
        };
        existing.count += 1;
        existing.totalDurationMs += input.durationMs;
        existing.lastStatusCode = input.statusCode;
        existing.lastSeenAt = new Date().toISOString();
        if (input.statusCode >= 400) {
            existing.errorCount += 1;
        }
        this.routes.set(key, existing);
        this.totalRequests += 1;
        this.totalDurationMs += input.durationMs;
        this.slowestRequestMs = Math.max(this.slowestRequestMs, input.durationMs);
        if (input.statusCode >= 400) {
            this.totalErrors += 1;
        }
    }
    recordError(input) {
        this.totalErrors += 1;
        this.recentErrors.unshift({
            at: new Date().toISOString(),
            requestId: input.requestId,
            method: input.method,
            path: input.path,
            statusCode: input.statusCode,
            message: input.message,
        });
        if (this.recentErrors.length > 20) {
            this.recentErrors.length = 20;
        }
    }
    recordBusinessEvent(input) {
        this.recentBusinessEvents.unshift({
            at: new Date().toISOString(),
            type: input.type,
            entityId: input.entityId,
            actorId: input.actorId,
            shipmentId: input.shipmentId,
            metadata: input.metadata,
        });
        if (this.recentBusinessEvents.length > 30) {
            this.recentBusinessEvents.length = 30;
        }
    }
    getSnapshot() {
        const uptimeMs = Date.now() - this.startedAt;
        const avgDurationMs = this.totalRequests > 0 ? this.totalDurationMs / this.totalRequests : 0;
        const hotRoutes = [...this.routes.values()]
            .sort((a, b) => b.count - a.count)
            .slice(0, 8)
            .map((route) => ({
            method: route.method,
            path: route.path,
            count: route.count,
            errorCount: route.errorCount,
            avgDurationMs: Number((route.totalDurationMs / Math.max(route.count, 1)).toFixed(1)),
            lastStatusCode: route.lastStatusCode,
            lastSeenAt: route.lastSeenAt,
        }));
        return {
            uptimeMs,
            totalRequests: this.totalRequests,
            totalErrors: this.totalErrors,
            avgDurationMs: Number(avgDurationMs.toFixed(1)),
            slowestRequestMs: this.slowestRequestMs,
            hotRoutes,
            recentErrors: [...this.recentErrors],
            recentBusinessEvents: [...this.recentBusinessEvents],
            memory: {
                rssMb: Number((process.memoryUsage().rss / 1024 / 1024).toFixed(1)),
                heapUsedMb: Number((process.memoryUsage().heapUsed / 1024 / 1024).toFixed(1)),
            },
        };
    }
}
exports.runtimeObservability = new RuntimeObservabilityStore();
//# sourceMappingURL=runtime-observability.js.map