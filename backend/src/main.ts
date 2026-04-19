import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import express from 'express';
import path from 'node:path';
import { GlobalExceptionFilter } from './common/observability/global-exception.filter';
import { RequestLoggingInterceptor } from './common/observability/request-logging.interceptor';
import { createRateLimitMiddleware } from './common/security/rate-limit.middleware';
import { AppModule } from './app.module';

async function bootstrap() {
  process.env.NODE_ENV = process.env.NODE_ENV?.trim() || 'production';

  const app = await NestFactory.create(AppModule);

  const corsOriginEnv =
    process.env.FRONTEND_URL?.trim() ??
    process.env.CORS_ORIGINS?.trim() ??
    process.env.CORS_ORIGIN?.trim();
  const corsOrigins = corsOriginEnv
    ? corsOriginEnv
        .split(',')
        .map((value) => value.trim())
        .filter((value) => value.length > 0)
    : false;

  app.enableCors({
    origin: corsOrigins,
    credentials: true,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
  });

  app.use(express.json({ limit: '50mb' }));
  app.use(express.urlencoded({ extended: true, limit: '50mb' }));
  app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));
  app.setGlobalPrefix('api');
  app.use(
    '/api/auth/login',
    createRateLimitMiddleware({
      keyPrefix: 'auth-login',
      limit: 10,
      windowMs: 15 * 60 * 1000,
    }),
  );
  app.use(
    '/api/auth/register/customer',
    createRateLimitMiddleware({
      keyPrefix: 'auth-register-customer',
      limit: 8,
      windowMs: 15 * 60 * 1000,
    }),
  );
  app.use(
    '/api/auth/register/traveler',
    createRateLimitMiddleware({
      keyPrefix: 'auth-register-traveler',
      limit: 6,
      windowMs: 15 * 60 * 1000,
    }),
  );
  app.use(
    '/api/storage/upload-base64',
    createRateLimitMiddleware({
      keyPrefix: 'storage-upload',
      limit: 30,
      windowMs: 15 * 60 * 1000,
    }),
  );
  app.use(
    '/api/offers',
    createRateLimitMiddleware({
      keyPrefix: 'offers',
      limit: 40,
      windowMs: 15 * 60 * 1000,
    }),
  );
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.useGlobalInterceptors(new RequestLoggingInterceptor());
  app.useGlobalFilters(new GlobalExceptionFilter());

  const port = Number(process.env.PORT ?? 10000);
  await app.listen(port, '0.0.0.0');
  console.log(`iway backend listening on ${port}`);
}

void bootstrap();
