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

type RouteBucket = {
  key: string;
  method: string;
  path: string;
  count: number;
  errorCount: number;
  totalDurationMs: number;
  lastStatusCode: number;
  lastSeenAt: string;
};

class RuntimeObservabilityStore {
  private readonly startedAt = Date.now();
  private totalRequests = 0;
  private totalErrors = 0;
  private totalDurationMs = 0;
  private slowestRequestMs = 0;
  private readonly routes = new Map<string, RouteBucket>();
  private readonly recentErrors: Array<{
    at: string;
    requestId?: string;
    method?: string;
    path?: string;
    statusCode: number;
    message: string;
  }> = [];
  private readonly recentBusinessEvents: Array<{
    at: string;
    type: string;
    entityId?: string;
    actorId?: string;
    shipmentId?: string;
    metadata?: Record<string, unknown>;
  }> = [];

  recordRequest(input: RequestMetricInput) {
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

  recordError(input: ErrorMetricInput) {
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

  recordBusinessEvent(input: {
    type: string;
    entityId?: string;
    actorId?: string;
    shipmentId?: string;
    metadata?: Record<string, unknown>;
  }) {
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

export const runtimeObservability = new RuntimeObservabilityStore();
