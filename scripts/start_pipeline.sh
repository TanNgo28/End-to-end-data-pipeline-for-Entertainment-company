#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
lifecycle_lock
if running oracle || running trino; then
  echo 'Run scripts/stop_pipeline.sh --serving-only before starting Flink.' >&2
  exit 1
fi
if running flink-jobmanager; then
  jobs=$(tool scripts/flink_admin.py jobs)
  if [[ -n "$jobs" ]]; then
    if [[ -s "$RUNTIME/bronze-job-id" && "$jobs" == "$(<"$RUNTIME/bronze-job-id") entertainment-kafka-bronze RUNNING" ]]; then
      printf 'Job is already running: %s\n' "$jobs"
      exit 0
    fi
    printf 'Flink slot is occupied:\n%s\n' "$jobs" >&2
    exit 1
  fi
fi
for directory in "$RUNTIME/flink-state" "$RUNTIME/flink-state/checkpoints" "$RUNTIME/flink-state/savepoints"; do
  [[ -d "$directory" ]] || mkdir -m 777 -- "$directory"
done
compose config -q
compose build flink-jobmanager tools
compose up -d --no-build kafka seaweedfs
scripts/init_topics.sh
compose up -d --no-build flink-jobmanager flink-taskmanager
tool scripts/flink_admin.py wait
scripts/init_iceberg.sh

settings=$(mktemp)
submit=$(mktemp)
trap 'rm -f -- "$settings" "$submit"' EXIT
if [[ -s "$RUNTIME/bronze-job-id" ]]; then
  restore=$(tool scripts/flink_admin.py restore "$(<"$RUNTIME/bronze-job-id")")
  printf "SET 'execution.state-recovery.path' = '%s';\n" "$restore" > "$settings"
fi
flink_sql flink/sql/catalog.sql flink/sql/kafka_source.sql "$settings" flink/sql/ingest.sql | tee "$submit"
job_id=$(sed -nE 's/.*Job ID: ([0-9a-f]{32}).*/\1/p' "$submit" | tail -n 1)
[[ "$job_id" =~ ^[0-9a-f]{32}$ ]] || { echo 'Flink did not report a job ID' >&2; exit 1; }
printf '%s\n' "$job_id" > "$RUNTIME/bronze-job-id.tmp"
mv -f -- "$RUNTIME/bronze-job-id.tmp" "$RUNTIME/bronze-job-id"
