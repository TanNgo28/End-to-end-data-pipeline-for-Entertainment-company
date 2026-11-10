#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
tool scripts/sync_gold_to_oracle.py "$@"
