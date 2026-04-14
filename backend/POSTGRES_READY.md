# iWay backend, Postgres production path

## Current reality
- Local development can stay on SQLite today.
- Production should move to PostgreSQL.
- This repo now supports both tracks deliberately, without rewriting the app.

## What is now ready
- `prisma/schema.postgres.prisma`
- `Dockerfile`
- `docker-compose.production.yml`
- `docker-compose.staging.yml`
- `.env.production.example`
- `.env.staging.example`
- `scripts/validate_production_env.sh`
- `scripts/smoke_deploy.sh`
- `scripts/backup_postgres.sh`
- `scripts/restore_postgres.sh`
- `DEPLOY_PRODUCTION.md`

## Why this path
The product is relational by nature: shipments, offers, chat, tracking, ratings, commissions, audit, notifications, device tokens. PostgreSQL is the correct production database.

## Cutover principle
Do not break local velocity.
- SQLite remains the fastest local dev path.
- PostgreSQL becomes the production deploy target.

## Production commands
```bash
cp .env.production.example .env.production
npm run deploy:check-env
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
npm run deploy:smoke
```

## Staging commands
```bash
cp .env.staging.example .env.staging
sh ./scripts/validate_production_env.sh .env.staging
docker compose -f docker-compose.staging.yml --env-file .env.staging up -d --build
APP_BASE_URL=http://127.0.0.1:3001 npm run deploy:smoke
```

## Before startup launch
- move PostgreSQL to managed service
- store secrets in provider secret manager
- schedule automated backups
- add HTTPS + reverse proxy
- run release QA on production-like env
