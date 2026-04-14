#!/bin/sh
set -eu

ARCHIVE_PATH=${1:-}
UPLOADS_DIR=${UPLOADS_DIR:-./uploads}

if [ -z "$ARCHIVE_PATH" ]; then
  echo "usage: sh ./scripts/restore_uploads.sh <archive.tar.gz>" >&2
  exit 1
fi

if [ ! -f "$ARCHIVE_PATH" ]; then
  echo "archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

mkdir -p "$UPLOADS_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$UPLOADS_DIR"

echo "uploads restored into $UPLOADS_DIR"
