#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
lifecycle_lock
if running flink-jobmanager || running flink-taskmanager; then
  echo 'Run scripts/stop_pipeline.sh --flink-only before serving on the PoC host.' >&2
  exit 1
fi
compose config -q
compose stop kafka
compose up -d --no-deps seaweedfs
compose up -d --no-deps --wait --wait-timeout 300 oracle
tool scripts/sync_gold_to_oracle.py --bootstrap
tool scripts/sync_gold_to_oracle.py
compose up -d --no-deps --wait --wait-timeout 180 trino
