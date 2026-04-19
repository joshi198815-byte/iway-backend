import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { runtimeObservability } from './runtime-observability';
import { dispatchOperationalAlert } from './alert-dispatcher';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('HTTP_EXCEPTION');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest();
    const res = ctx.getResponse();

    const requestId = req.requestId || req.headers['x-request-id']?.toString() || 'unknown';
    const isHttpException = exception instanceof HttpException;
    const status = isHttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;
    const response = isHttpException ? exception.getResponse() : null;

    const payload =
      typeof response === 'object' && response !== null
        ? response
        : {
            statusCode: status,
            message: isHttpException ? response : 'Error interno del servidor',
          };

    const errorMessage =
      typeof payload === 'object' && payload !== null && 'message' in payload
        ? String((payload as { message?: unknown }).message)
        : 'Error interno del servidor';

    runtimeObservability.recordError({
      requestId,
      method: req.method,
      path: req.originalUrl || req.url,
      statusCode: status,
      message: errorMessage,
    });

    void dispatchOperationalAlert({
      requestId,
      method: req.method,
      path: req.originalUrl || req.url,
      statusCode: status,
      message: errorMessage,
    });

    this.logger.error(
      JSON.stringify({
        requestId,
        method: req.method,
        path: req.originalUrl || req.url,
        statusCode: status,
        userId: req.user?.sub ?? null,
        role: req.user?.role ?? null,
        error: payload,
      }),
    );

    res.status(status).json({
      ...(typeof payload === 'object' && payload !== null ? payload : { message: payload }),
      requestId,
    });
  }
}
