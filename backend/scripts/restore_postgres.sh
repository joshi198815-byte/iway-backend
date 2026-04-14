#!/bin/sh
set -eu

DUMP_FILE=${1:-}

if [ -z "$DUMP_FILE" ] || [ ! -f "$DUMP_FILE" ]; then
  echo "usage: $0 <backup.dump>" >&2
  exit 1
fi

: "${POSTGRES_DB:=iway}"
: "${POSTGRES_USER:=iway}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${POSTGRES_HOST:=127.0.0.1}"
: "${POSTGRES_PORT:=5432}"

export PGPASSWORD="$POSTGRES_PASSWORD"
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --host="$POSTGRES_HOST" \
  --port="$POSTGRES_PORT" \
  --username="$POSTGRES_USER" \
  --dbname="$POSTGRES_DB" \
  "$DUMP_FILE"

echo "restore completed from $DUMP_FILE"
