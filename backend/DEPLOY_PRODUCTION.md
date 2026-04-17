# iWay production deploy

## Goal
Keep local SQLite development intact, but ship production on PostgreSQL without a rewrite.

## Files added
- `prisma/schema.postgres.prisma`
- `.env.production.example`
- `.env.staging.example`
- `docker-compose.production.yml`
- `docker-compose.staging.yml`
- `Dockerfile`
- `deploy/nginx/iway.production.conf`
- `deploy/nginx/iway.staging.conf`
- `scripts/backup_postgres.sh`
- `scripts/backup_uploads.sh`
- `scripts/restore_uploads.sh`
- `scripts/apply_postgres_schema.sh`
- `scripts/check_external_health.sh`
- `scripts/rollback_release.sh`
- `prisma/seed.staging.ts`
- `STORAGE_POLICY.md`

## 1. Prepare secrets
```bash
cp .env.production.example .env.production
npm run deploy:check-env
```

Set at minimum:
- `POSTGRES_PASSWORD` in shell or secret manager
- `JWT_SECRET` long random value
- Firebase keys if push will run in production
- `CORS_ORIGIN` to your real app domain, avoid `*` in production (for iway.one, use `https://iway.one`)
- `APP_BASE_URL` to your API domain (for this deploy, use `https://api.iway.one`)

## 2. Apply schema safely
```bash
npm run db:apply:production
```

This validates env, creates a pre-apply backup, then runs Prisma push against `prisma/schema.postgres.prisma`.

## 3. Start stack
```bash
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

## 4. Validate
```bash
npm run deploy:smoke
npm run health:external -- https://api.iway.one
```

## 5. Backup
Run from a host with `pg_dump` available:
```bash
POSTGRES_PASSWORD=... POSTGRES_HOST=127.0.0.1 ./scripts/backup_postgres.sh
sh ./scripts/backup_uploads.sh
```
Back up database and uploads on the same cadence.

## 6. Restore drill
Run from a host with `pg_restore` available:
```bash
POSTGRES_PASSWORD=... POSTGRES_HOST=127.0.0.1 ./scripts/restore_postgres.sh ./backups/iway-YYYYMMDDTHHMMSSZ.dump
sh ./scripts/restore_uploads.sh ./backups/uploads/iway-uploads-YYYYMMDDTHHMMSSZ.tar.gz
```

## 7. Staging
```bash
cp .env.staging.example .env.staging
sh ./scripts/validate_production_env.sh .env.staging
npm run db:apply:staging
npm run seed:staging
docker compose -f docker-compose.staging.yml --env-file .env.staging up -d --build
APP_BASE_URL=http://127.0.0.1:3001 npm run deploy:smoke
APP_BASE_URL=http://127.0.0.1:3001 npm run health:external
```

## 8. Reverse proxy and HTTPS
Use the provided Nginx references:
- `deploy/nginx/iway.production.conf`
- `deploy/nginx/iway.staging.conf`

Terminate TLS at the proxy and pass `/api` plus websocket traffic to the backend container.

## 9. Rollback
Keep the previous backend image tag available and run:
```bash
sh ./scripts/rollback_release.sh <previous-image-tag>
```

## 10. CI/CD minimum
Use the included GitHub Actions workflow to validate backend build/typecheck, env examples, compose config, and Docker image build on push.

## Notes
- Production uses `prisma/schema.postgres.prisma` deliberately.
- Local dev can continue on SQLite with the existing `schema.prisma`.
- The container entrypoint now validates critical secrets before boot and runs Prisma push explicitly.
- Before public launch, move DB to managed Postgres and store secrets outside flat files.
