#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
for ((attempt = 1; attempt <= 12; attempt++)); do
  if timeout 10s "${COMPOSE[@]}" exec -T kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server kafka:9092 --create --if-not-exists \
    --topic streaming-events --partitions 1 --replication-factor 1; then
    compose exec -T kafka /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server kafka:9092 --describe --topic streaming-events
    exit 0
  fi
  sleep 2
done
echo 'Kafka topic initialization failed.' >&2
exit 1
