#!/bin/sh
set -eu

PREVIOUS_IMAGE=${1:-}
COMPOSE_FILE=${COMPOSE_FILE:-docker-compose.production.yml}
ENV_FILE=${ENV_FILE:-.env.production}

if [ -z "$PREVIOUS_IMAGE" ]; then
  echo "usage: sh ./scripts/rollback_release.sh <previous-image-tag>" >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "env file not found: $ENV_FILE" >&2
  exit 1
fi

export IWAY_BACKEND_IMAGE="$PREVIOUS_IMAGE"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d backend

echo "rollback requested to image: $PREVIOUS_IMAGE"
