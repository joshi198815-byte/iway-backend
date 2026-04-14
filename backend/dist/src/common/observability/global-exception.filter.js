"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.GlobalExceptionFilter = void 0;
const common_1 = require("@nestjs/common");
const runtime_observability_1 = require("./runtime-observability");
const alert_dispatcher_1 = require("./alert-dispatcher");
let GlobalExceptionFilter = class GlobalExceptionFilter {
    constructor() {
        this.logger = new common_1.Logger('HTTP_EXCEPTION');
    }
    catch(exception, host) {
        const ctx = host.switchToHttp();
        const req = ctx.getRequest();
        const res = ctx.getResponse();
        const requestId = req.requestId || req.headers['x-request-id']?.toString() || 'unknown';
        const isHttpException = exception instanceof common_1.HttpException;
        const status = isHttpException
            ? exception.getStatus()
            : common_1.HttpStatus.INTERNAL_SERVER_ERROR;
        const response = isHttpException ? exception.getResponse() : null;
        const payload = typeof response === 'object' && response !== null
            ? response
            : {
                statusCode: status,
                message: isHttpException ? response : 'Internal server error',
            };
        const errorMessage = typeof payload === 'object' && payload !== null && 'message' in payload
            ? String(payload.message)
            : 'Internal server error';
        runtime_observability_1.runtimeObservability.recordError({
            requestId,
            method: req.method,
            path: req.originalUrl || req.url,
            statusCode: status,
            message: errorMessage,
        });
        void (0, alert_dispatcher_1.dispatchOperationalAlert)({
            requestId,
            method: req.method,
            path: req.originalUrl || req.url,
            statusCode: status,
            message: errorMessage,
        });
        this.logger.error(JSON.stringify({
            requestId,
            method: req.method,
            path: req.originalUrl || req.url,
            statusCode: status,
            userId: req.user?.sub ?? null,
            role: req.user?.role ?? null,
            error: payload,
        }));
        res.status(status).json({
            ...(typeof payload === 'object' && payload !== null ? payload : { message: payload }),
            requestId,
        });
    }
};
exports.GlobalExceptionFilter = GlobalExceptionFilter;
exports.GlobalExceptionFilter = GlobalExceptionFilter = __decorate([
    (0, common_1.Catch)()
], GlobalExceptionFilter);
//# sourceMappingURL=global-exception.filter.js.map