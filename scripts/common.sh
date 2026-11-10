#!/usr/bin/env bash
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
if [[ ! -f .env ]]; then
  echo 'Run scripts/init_env.sh first.' >&2
  exit 1
fi
RUNTIME="$ROOT/.runtime"
mkdir -p -m 700 -- "$RUNTIME"
COMPOSE=(docker compose --env-file "$ROOT/.env" -f "$ROOT/compose.yaml"
  --profile ingest --profile serve --profile tools)

compose() { "${COMPOSE[@]}" "$@"; }
tool() { compose run --rm -T --no-deps tools python "$@"; }
running() { [[ -n $(compose ps --status running -q "$1") ]]; }

lifecycle_lock() {
  exec 9>"$RUNTIME/lifecycle.lock"
  flock -x 9
}

flink_sql() {
  local log status=0
  log=$(mktemp)
  cat "$@" | compose exec -T -e JVM_ARGS=-Xmx384m flink-jobmanager \
    /opt/flink/bin/sql-client.sh -f /dev/stdin 2>&1 | tee "$log" || status=$?
  if grep -Eq '\[ERROR\]|Could not execute SQL|Exception in thread' "$log"; then
    status=1
  fi
  rm -f -- "$log"
  return "$status"
}
