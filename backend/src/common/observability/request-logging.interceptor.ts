import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { runtimeObservability } from './runtime-observability';

@Injectable()
export class RequestLoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const http = context.switchToHttp();
    const req = http.getRequest();
    const res = http.getResponse();

    const requestId = req.headers['x-request-id']?.toString() || randomUUID();
    const startedAt = Date.now();

    req.requestId = requestId;
    res.setHeader('x-request-id', requestId);

    return next.handle().pipe(
      tap({
        next: () => {
          if (req.url?.includes('/health')) {
            return;
          }

          const path = req.originalUrl || req.url;
          const durationMs = Date.now() - startedAt;

          runtimeObservability.recordRequest({
            method: req.method,
            path,
            statusCode: res.statusCode,
            durationMs,
          });

          this.logger.log(
            JSON.stringify({
              requestId,
              method: req.method,
              path,
              statusCode: res.statusCode,
              durationMs,
              userId: req.user?.sub ?? null,
              role: req.user?.role ?? null,
              ip: req.ip ?? null,
            }),
          );
        },
      }),
    );
  }
}
