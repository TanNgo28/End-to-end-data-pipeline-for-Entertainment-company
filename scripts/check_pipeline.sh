#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
compose ps -a
if running flink-jobmanager && [[ -s "$RUNTIME/bronze-job-id" ]]; then
  tool scripts/flink_admin.py checkpoints "$(<"$RUNTIME/bronze-job-id")"
fi
if [[ $# -gt 0 ]]; then
  tool scripts/lakehouse.py verify-bronze "$@"
fi
