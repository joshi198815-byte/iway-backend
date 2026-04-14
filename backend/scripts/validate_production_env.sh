#!/bin/sh
set -eu

ENV_FILE=${1:-.env.production}

if [ ! -f "$ENV_FILE" ]; then
  echo "env file not found: $ENV_FILE" >&2
  exit 1
fi

case "$ENV_FILE" in
  /*) ENV_SOURCE="$ENV_FILE" ;;
  *) ENV_SOURCE="./$ENV_FILE" ;;
esac

# shellcheck disable=SC1090
set -a
. "$ENV_SOURCE"
set +a

fail=0
warn() { echo "WARN: $1"; }
err() { echo "ERROR: $1" >&2; fail=1; }

[ -n "${DATABASE_URL:-}" ] || err "DATABASE_URL is required"
[ -n "${JWT_SECRET:-}" ] || err "JWT_SECRET is required"
[ -n "${APP_BASE_URL:-}" ] || warn "APP_BASE_URL is empty"

JWT_SECRET_LEN=$(printf '%s' "${JWT_SECRET:-}" | wc -c | tr -d ' ')
if [ "${JWT_SECRET:-}" = "replace-with-long-random-secret" ] || [ "$JWT_SECRET_LEN" -lt 24 ]; then
  err "JWT_SECRET must be replaced with a strong secret (min 24 chars)"
fi

case "${DATABASE_URL:-}" in
  *iway_change_me*|*replace-me*) err "DATABASE_URL still contains placeholder credentials" ;;
esac

if [ "${CORS_ORIGIN:-}" = "*" ]; then
  warn "CORS_ORIGIN is wildcard"
fi

if [ -z "${POSTGRES_PASSWORD:-}" ]; then
  warn "POSTGRES_PASSWORD is not exported separately; ensure compose/env secret source provides it"
fi

if [ $fail -ne 0 ]; then
  exit 1
fi

echo "Production env looks sane: $ENV_FILE"
