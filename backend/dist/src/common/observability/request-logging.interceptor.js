"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RequestLoggingInterceptor = void 0;
const common_1 = require("@nestjs/common");
const node_crypto_1 = require("node:crypto");
const operators_1 = require("rxjs/operators");
const runtime_observability_1 = require("./runtime-observability");
let RequestLoggingInterceptor = class RequestLoggingInterceptor {
    constructor() {
        this.logger = new common_1.Logger('HTTP');
    }
    intercept(context, next) {
        const http = context.switchToHttp();
        const req = http.getRequest();
        const res = http.getResponse();
        const requestId = req.headers['x-request-id']?.toString() || (0, node_crypto_1.randomUUID)();
        const startedAt = Date.now();
        req.requestId = requestId;
        res.setHeader('x-request-id', requestId);
        return next.handle().pipe((0, operators_1.tap)({
            next: () => {
                if (req.url?.includes('/health')) {
                    return;
                }
                const path = req.originalUrl || req.url;
                const durationMs = Date.now() - startedAt;
                runtime_observability_1.runtimeObservability.recordRequest({
                    method: req.method,
                    path,
                    statusCode: res.statusCode,
                    durationMs,
                });
                this.logger.log(JSON.stringify({
                    requestId,
                    method: req.method,
                    path,
                    statusCode: res.statusCode,
                    durationMs,
                    userId: req.user?.sub ?? null,
                    role: req.user?.role ?? null,
                    ip: req.ip ?? null,
                }));
            },
        }));
    }
};
exports.RequestLoggingInterceptor = RequestLoggingInterceptor;
exports.RequestLoggingInterceptor = RequestLoggingInterceptor = __decorate([
    (0, common_1.Injectable)()
], RequestLoggingInterceptor);
//# sourceMappingURL=request-logging.interceptor.js.map