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
      echo "timeout waiting for $URL" >&2
      exit 1
    fi

    sleep 2
  done
}

wait_for "$BASE_URL/api/health/live" /tmp/iway-health-live.json
wait_for "$BASE_URL/api/health/ready" /tmp/iway-health-ready.json
wait_for "$BASE_URL/api/health/metrics" /tmp/iway-health-metrics.json

echo "live:"
cat /tmp/iway-health-live.json
printf '\nready:\n'
cat /tmp/iway-health-ready.json
printf '\nmetrics:\n'
cat /tmp/iway-health-metrics.json
printf '\nexternal health check ok for %s\n' "$BASE_URL"
