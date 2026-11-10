#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
run_id=${1:-compose-demo}
count=${2:-240}
scripts/init_env.sh
scripts/start_pipeline.sh
scripts/produce_demo.sh --run-id "$run_id" --count "$count"
printf -v event_id '%s-%04d' "$run_id" "$count"
scripts/check_pipeline.sh "$event_id" --wait 120
scripts/refresh_lakehouse.sh
scripts/stop_pipeline.sh --flink-only
scripts/start_serving.sh
scripts/export_dashboard.sh
