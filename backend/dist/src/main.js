"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("reflect-metadata");
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const express_1 = __importDefault(require("express"));
const node_path_1 = __importDefault(require("node:path"));
const global_exception_filter_1 = require("./common/observability/global-exception.filter");
const request_logging_interceptor_1 = require("./common/observability/request-logging.interceptor");
const rate_limit_middleware_1 = require("./common/security/rate-limit.middleware");
const app_module_1 = require("./app.module");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.use('/uploads', express_1.default.static(node_path_1.default.join(process.cwd(), 'uploads')));
    app.setGlobalPrefix('api');
    app.use('/api/auth/login', (0, rate_limit_middleware_1.createRateLimitMiddleware)({
        keyPrefix: 'auth-login',
        limit: 10,
        windowMs: 15 * 60 * 1000,
    }));
    app.use('/api/auth/register/customer', (0, rate_limit_middleware_1.createRateLimitMiddleware)({
        keyPrefix: 'auth-register-customer',
        limit: 8,
        windowMs: 15 * 60 * 1000,
    }));
    app.use('/api/auth/register/traveler', (0, rate_limit_middleware_1.createRateLimitMiddleware)({
        keyPrefix: 'auth-register-traveler',
        limit: 6,
        windowMs: 15 * 60 * 1000,
    }));
    app.use('/api/storage/upload-base64', (0, rate_limit_middleware_1.createRateLimitMiddleware)({
        keyPrefix: 'storage-upload',
        limit: 30,
        windowMs: 15 * 60 * 1000,
    }));
    app.use('/api/offers', (0, rate_limit_middleware_1.createRateLimitMiddleware)({
        keyPrefix: 'offers',
        limit: 40,
        windowMs: 15 * 60 * 1000,
    }));
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
    }));
    app.useGlobalInterceptors(new request_logging_interceptor_1.RequestLoggingInterceptor());
    app.useGlobalFilters(new global_exception_filter_1.GlobalExceptionFilter());
    const port = Number(process.env.PORT ?? 3000);
    await app.listen(port, '0.0.0.0');
    console.log(`iway backend listening on ${port}`);
}
void bootstrap();
//# sourceMappingURL=main.js.map