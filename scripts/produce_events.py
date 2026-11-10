"""Generate repeatable synthetic watch events and check Kafka delivery."""
import argparse
from datetime import datetime, timedelta, timezone
import json
import os
import random
import re
import time
import uuid

from confluent_kafka import Consumer, Producer, TopicPartition

TOPIC = "streaming-events"


def events(run_id, count):
    rng = random.Random(run_id)
    base = datetime(2026, 11, 9, 19, 0, tzinfo=timezone.utc)
    for number in range(count):
        event_type = rng.choices(
            ("play", "pause", "resume", "complete", "stop"), (4, 2, 2, 2, 1)
        )[0]
        yield {
            "event_id": f"{run_id}-{number + 1:04d}",
            "user_id": f"usr_demo_{rng.randint(1, 32):03d}",
            "content_id": f"movie_demo_{rng.randint(1, 12):02d}",
            "event_type": event_type,
            "watch_duration_seconds": 0 if event_type in {"play", "resume"} else rng.randint(1, 360),
            "device": rng.choice(("smart_tv", "mobile", "web", "tablet")),
            "event_timestamp": (base + timedelta(days=number % 7, seconds=number)).isoformat().replace("+00:00", "Z"),
        }


def verify(bootstrap, expected):
    by_partition = {}
    for partition, offset in expected:
        by_partition[partition] = min(offset, by_partition.get(partition, offset))
    consumer = Consumer({
        "bootstrap.servers": bootstrap,
        "group.id": "entertainment-verify-" + uuid.uuid4().hex,
        "enable.auto.commit": False,
    })
    pending = dict(expected)
    try:
        consumer.assign([TopicPartition(TOPIC, p, offset) for p, offset in by_partition.items()])
        deadline = time.monotonic() + 30
        while pending and time.monotonic() < deadline:
            message = consumer.poll(1)
            if message is None:
                continue
            if message.error():
                raise RuntimeError(message.error())
            key = (message.partition(), message.offset())
            if key in pending and json.loads(message.value()) != pending.pop(key):
                raise RuntimeError(f"Kafka read-back differs at {key}")
        if pending:
            raise RuntimeError(f"Kafka read-back timed out with {len(pending)} events missing")
    finally:
        consumer.close()
    print(f"Kafka consumer verified {len(expected)} acknowledged events.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", default="demo")
    parser.add_argument("--count", type=int, default=240)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,48}", args.run_id):
        parser.error("--run-id must be 1–48 ASCII letters, digits, hyphens or underscores")
    if not 1 <= args.count <= 500:
        parser.error("--count must be between 1 and 500")

    bootstrap = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9094")
    producer = Producer({"bootstrap.servers": bootstrap, "enable.idempotence": True})
    delivered, failures = {}, []

    def ack(error, message):
        if error:
            failures.append(str(error))
        else:
            delivered[(message.partition(), message.offset())] = json.loads(message.value())

    for event in events(args.run_id, args.count):
        producer.produce(TOPIC, key=event["event_id"], value=json.dumps(event), on_delivery=ack)
        producer.poll(0)
    if producer.flush(30) or failures or len(delivered) != args.count:
        raise RuntimeError(f"Kafka delivery incomplete: {len(delivered)}/{args.count}; {failures}")
    print(f"Kafka acknowledged {len(delivered)} events at offsets {min(delivered)} through {max(delivered)}.")
    if args.verify:
        verify(bootstrap, delivered)
    print(f"Last event ID: {args.run_id}-{args.count:04d}")


if __name__ == "__main__":
    main()
