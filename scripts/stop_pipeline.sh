#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
if [[ $# -gt 1 || (${1:-} != '' && ${1:-} != '--flink-only' && ${1:-} != '--serving-only') ]]; then
  echo 'Usage: scripts/stop_pipeline.sh [--flink-only | --serving-only]' >&2
  exit 2
fi
lifecycle_lock
if [[ ${1:-} == --serving-only ]]; then
  compose stop trino oracle
  exit
fi
if running flink-jobmanager; then
  jobs=$(tool scripts/flink_admin.py jobs)
  if [[ -n "$jobs" ]]; then
    if [[ ! -s "$RUNTIME/bronze-job-id" || "$jobs" != "$(<"$RUNTIME/bronze-job-id") entertainment-kafka-bronze RUNNING" ]]; then
      printf 'Cannot safely stop Flink with these active jobs:\n%s\n' "$jobs" >&2
      exit 1
    fi
    compose exec -T -e JVM_ARGS=-Xmx384m flink-jobmanager /opt/flink/bin/flink \
      stop --savepointPath file:///opt/flink/pipeline-state/savepoints "$(<"$RUNTIME/bronze-job-id")"
  fi
fi
compose stop flink-taskmanager flink-jobmanager
if [[ ${1:-} != --flink-only ]]; then
  compose stop trino oracle kafka seaweedfs
fi
