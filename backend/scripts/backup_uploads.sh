#!/bin/sh
set -eu

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
UPLOADS_DIR=${UPLOADS_DIR:-./uploads}
OUT_DIR=${BACKUP_DIR:-./backups/uploads}
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

mkdir -p "$OUT_DIR"

if [ ! -d "$UPLOADS_DIR" ]; then
  echo "uploads directory not found: $UPLOADS_DIR" >&2
  exit 1
fi

ARCHIVE="$OUT_DIR/iway-uploads-$STAMP.tar.gz"
tar -czf "$ARCHIVE" -C "$UPLOADS_DIR" .
find "$OUT_DIR" -type f -name 'iway-uploads-*.tar.gz' -mtime +"$RETENTION_DAYS" -delete

echo "uploads backup written to $ARCHIVE"
