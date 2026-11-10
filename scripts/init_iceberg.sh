#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
# SeaweedFS mini creates the table bucket through S3_TABLE_BUCKET at startup.
tool scripts/lakehouse.py wait-catalog
flink_sql flink/sql/catalog.sql flink/sql/bronze.sql
