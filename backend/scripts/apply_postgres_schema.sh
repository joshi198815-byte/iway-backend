#!/bin/sh
set -eu

ENV_FILE=${1:-.env.production}
SCHEMA=${PRISMA_SCHEMA:-prisma/schema.postgres.prisma}

if [ ! -f "$ENV_FILE" ]; then
  echo "env file not found: $ENV_FILE" >&2
  exit 1
fi

case "$ENV_FILE" in
  /*) ENV_SOURCE="$ENV_FILE" ;;
  *) ENV_SOURCE="./$ENV_FILE" ;;
esac

set -a
. "$ENV_SOURCE"
set +a

: "${DATABASE_URL:?DATABASE_URL is required}"

echo "validating environment from $ENV_FILE"
sh ./scripts/validate_production_env.sh "$ENV_FILE"

if command -v pg_dump >/dev/null 2>&1; then
  echo "backing up postgres before schema apply"
  POSTGRES_HOST=${POSTGRES_HOST:-127.0.0.1} \
  POSTGRES_PORT=${POSTGRES_PORT:-5432} \
  POSTGRES_DB=${POSTGRES_DB:-iway} \
  POSTGRES_USER=${POSTGRES_USER:-iway} \
  POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-} \
  BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7} \
  sh ./scripts/backup_postgres.sh
else
  echo "WARN: pg_dump not found, skipping pre-apply logical backup" >&2
fi

echo "applying prisma schema: $SCHEMA"
npx prisma db push --schema "$SCHEMA"

echo "schema apply complete"
