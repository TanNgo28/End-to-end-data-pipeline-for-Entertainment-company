#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
lifecycle_lock
if running flink-jobmanager || running flink-taskmanager; then
  echo 'Run scripts/stop_pipeline.sh --flink-only before serving on the PoC host.' >&2
  exit 1
fi
wait_healthy() {
  local service=$1 timeout=$2 container state deadline
  container=$(compose ps -a -q "$service")
  deadline=$((SECONDS + timeout))
  while ((SECONDS < deadline)); do
    state=$(docker inspect --format '{{.State.Status}} {{.State.Health.Status}}' "$container")
    case "$state" in
      'running healthy') return 0 ;;
      running\ *) sleep 3 ;;
      *) printf '%s exited before becoming ready (%s)\n' "$service" "$state" >&2; return 1 ;;
    esac
  done
  printf '%s did not become healthy within %s seconds (%s)\n' "$service" "$timeout" "$state" >&2
  return 1
}

compose config -q
compose stop kafka
compose up -d --no-deps seaweedfs
compose up -d --no-deps oracle
wait_healthy oracle 300
tool scripts/sync_gold_to_oracle.py --bootstrap
tool scripts/sync_gold_to_oracle.py
compose up -d --no-deps trino
wait_healthy trino 180
