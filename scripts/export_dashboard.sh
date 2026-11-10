#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
directory="${1:-$RUNTIME/exports}"
mkdir -p -- "$directory"
pending=$(mktemp -d "$directory/.pending.XXXXXX")
trap 'rm -f -- "$pending"/*.csv; rmdir "$pending"' EXIT
for dataset in content_popularity top_10 device_engagement streaming_kpis reconcile; do
  compose exec -T -e JAVA_TOOL_OPTIONS=-Xmx128m trino trino --server http://localhost:8080 --user lakehouse \
    --output-format CSV_HEADER --execute "$(<"trino/sql/$dataset.sql")" > "$pending/$dataset.csv"
done
diff -u <(printf '"dataset","mismatches"\n"content_popularity","0"\n"device_engagement","0"\n"streaming_kpis","0"\n') "$pending/reconcile.csv"
mv -f -- "$pending"/*.csv "$directory/"
printf 'Trino reconciliation passed. CSVs are in %s\n' "$directory"
