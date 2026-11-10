#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
project=${1:-entertainment-lakehouse}
flink_port=${2:-8081}
trino_port=${3:-8080}
if [[ $# -gt 3 || ! $project =~ ^[a-z0-9][a-z0-9_-]*$ ||
      ! $flink_port =~ ^[1-9][0-9]{0,4}$ || ! $trino_port =~ ^[1-9][0-9]{0,4}$ ]] ||
   ((flink_port > 65535 || trino_port > 65535 || flink_port == trino_port)); then
  echo 'Usage: scripts/init_env.sh [compose-project [flink-port trino-port]]' >&2
  exit 2
fi
if [[ -e .env ]]; then
  echo 'Using existing .env'
  exit 0
fi
random_hex() { od -An -N 24 -tx1 /dev/urandom | tr -d ' \n'; }
umask 077
set -o noclobber
cat > .env <<EOF
COMPOSE_PROJECT_NAME=$project
FLINK_PORT=$flink_port
TRINO_PORT=$trino_port
LOCAL_UID=$(id -u)
LOCAL_GID=$(id -g)
AWS_ACCESS_KEY_ID=lake$(random_hex)
AWS_SECRET_ACCESS_KEY=$(random_hex)
ORACLE_PWD=DbA9$(random_hex)
ORACLE_ANALYTICS_PASSWORD=DbB9$(random_hex)
EOF
echo "Created private .env for $project"
