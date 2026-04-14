#!/bin/sh
set -eu

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT_DIR=${BACKUP_DIR:-./backups}
mkdir -p "$OUT_DIR"

: "${POSTGRES_DB:=iway}"
: "${POSTGRES_USER:=iway}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${POSTGRES_HOST:=127.0.0.1}"
: "${POSTGRES_PORT:=5432}"

export PGPASSWORD="$POSTGRES_PASSWORD"
pg_dump \
  --host="$POSTGRES_HOST" \
  --port="$POSTGRES_PORT" \
  --username="$POSTGRES_USER" \
  --dbname="$POSTGRES_DB" \
  --format=custom \
  --file="$OUT_DIR/iway-$STAMP.dump"

find "$OUT_DIR" -type f -name '*.dump' -mtime +${BACKUP_RETENTION_DAYS:-7} -delete
echo "backup written to $OUT_DIR/iway-$STAMP.dump"
