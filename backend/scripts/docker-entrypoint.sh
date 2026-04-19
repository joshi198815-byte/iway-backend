#!/bin/sh
set -eu

SCHEMA=${PRISMA_SCHEMA:-prisma/schema.postgres.prisma}

if [ "${NODE_ENV:-production}" != "production" ]; then
  echo "[entrypoint] warning: NODE_ENV=${NODE_ENV:-unset}"
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "[entrypoint] DATABASE_URL is required" >&2
  exit 1
fi

if [ -z "${JWT_SECRET:-}" ]; then
  echo "[entrypoint] JWT_SECRET is required" >&2
  exit 1
fi

if [ "${JWT_SECRET}" = "replace-with-long-random-secret" ] || [ ${#JWT_SECRET} -lt 24 ]; then
  echo "[entrypoint] JWT_SECRET must be a real secret with at least 24 characters" >&2
  exit 1
fi

if [ "${CORS_ORIGIN:-}" = "*" ]; then
  echo "[entrypoint] warning: CORS_ORIGIN is wildcard in production"
fi

echo "[entrypoint] applying Prisma migrations with schema: ${SCHEMA}"
npx prisma migrate deploy --schema "$SCHEMA"

echo "[entrypoint] starting backend"
exec node dist/src/main.js
