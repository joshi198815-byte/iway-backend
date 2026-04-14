#!/bin/sh
set -eu

BASE_URL=${1:-${APP_BASE_URL:-http://127.0.0.1:3000}}
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-60}
START_TS=$(date +%s)

wait_for() {
  URL=$1
  OUT=$2
  while :; do
    if wget -qO- "$URL" >"$OUT" 2>/dev/null; then
      return 0
    fi

    NOW=$(date +%s)
    if [ $((NOW - START_TS)) -ge "$TIMEOUT_SECONDS" ]; then
      echo "smoke check failed: timeout waiting for $URL" >&2
      exit 1
    fi

    sleep 2
  done
}

wait_for "$BASE_URL/api/health" /tmp/iway-smoke-health.json
wait_for "$BASE_URL/api/health/live" /tmp/iway-smoke-live.json
wait_for "$BASE_URL/api/health/ready" /tmp/iway-smoke-ready.json
wait_for "$BASE_URL/api/health/metrics" /tmp/iway-smoke-metrics.json

echo "health response:"
cat /tmp/iway-smoke-health.json
printf '\n\nlive response:\n'
cat /tmp/iway-smoke-live.json
printf '\n\nready response:\n'
cat /tmp/iway-smoke-ready.json
printf '\n\nmetrics response:\n'
cat /tmp/iway-smoke-metrics.json

echo
printf 'smoke check ok for %s\n' "$BASE_URL"
