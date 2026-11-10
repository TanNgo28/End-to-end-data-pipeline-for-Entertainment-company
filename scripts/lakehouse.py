"""Local Iceberg catalog access and bounded snapshot materialization."""
import argparse
from collections import defaultdict
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import time
from urllib.parse import parse_qsl, urlsplit, urlunsplit

from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from botocore.credentials import Credentials
import pyarrow as pa
from pyiceberg.catalog.rest import RestCatalog
from pyiceberg.expressions import EqualTo
from pyiceberg.exceptions import RESTError
from requests import RequestException
from requests.auth import AuthBase

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / ".runtime"
PUBLISHED = DATA / "gold-publication.json"
BRONZE = "bronze.streaming_events"
SILVER = "silver.streaming_events_clean"
GOLD = ("gold.content_popularity", "gold.device_engagement", "gold.streaming_kpis")
MAX_ROWS = 100_000
EVENT_TYPES = {"PLAY", "PAUSE", "COMPLETE", "RESUME", "STOP"}


def credentials():
    return Credentials(os.environ["AWS_ACCESS_KEY_ID"], os.environ["AWS_SECRET_ACCESS_KEY"])


class SeaweedAuth(AuthBase):
    """Sign the transmitted JSON bytes, including the payload hash for POST."""

    def __call__(self, request):
        url = urlsplit(request.url)
        body = request.body or b""
        if isinstance(body, str):
            body = body.encode("utf-8")
        request.headers["x-amz-content-sha256"] = hashlib.sha256(body).hexdigest()
        signed = AWSRequest(
            method=request.method,
            url=urlunsplit(url._replace(query="")),
            params=parse_qsl(url.query, keep_blank_values=True),
            data=body,
            headers={k: v for k, v in request.headers.items() if k.lower() != "connection"},
        )
        SigV4Auth(credentials(), "s3", "us-east-1").add_auth(signed)
        request.headers.update(dict(signed.headers))
        return request


class SeaweedCatalog(RestCatalog):
    def _create_session(self):
        session = super()._create_session()
        session.auth = SeaweedAuth()
        return session


def catalog():
    creds = credentials()
    return SeaweedCatalog(
        "entertainment",
        uri=os.environ["ICEBERG_REST_URI"],
        warehouse="s3://entertainment-iceberg",
        **{
            "py-io-impl": "pyiceberg.io.pyarrow.PyArrowFileIO",
            "s3.endpoint": os.environ["S3_ENDPOINT"],
            "s3.region": "us-east-1",
            "s3.access-key-id": creds.access_key,
            "s3.secret-access-key": creds.secret_key,
        },
    )


@contextmanager
def publication_lock():
    DATA.mkdir(exist_ok=True)
    with (DATA / ".publication.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def read_rows(table, snapshot_id):
    arrow = table.scan(snapshot_id=snapshot_id, limit=MAX_ROWS + 1).to_arrow()
    if arrow.num_rows > MAX_ROWS:
        raise RuntimeError(f"PoC scan limit of {MAX_ROWS:,} rows exceeded")
    return arrow.to_pylist()


def clean_rows(rows):
    clean = {}
    # Kafka partition/offset is the tie-breaker for legacy or replayed Bronze rows.
    ordered = sorted(rows, key=lambda row: (
        row["kafka_partition"] is None,
        row["kafka_partition"] or 0,
        row["kafka_offset"] or 0,
    ))
    for row in ordered:
        event_id, user_id, content_id, device, event_type = (
            (row[field] or "").strip() for field in
            ("event_id", "user_id", "content_id", "device", "event_type")
        )
        event_type = event_type.upper()
        if not all((event_id, user_id, content_id, device, row["event_timestamp"])):
            continue
        if event_type not in EVENT_TYPES:
            continue
        clean.setdefault(event_id, {
            **row, "event_id": event_id, "user_id": user_id, "content_id": content_id,
            "device": device.lower(), "event_type": event_type,
            "watch_duration_seconds": max(0, row["watch_duration_seconds"] or 0),
        })
    return [clean[key] for key in sorted(clean)]


def aggregate(rows):
    contents = defaultdict(lambda: {"plays": 0, "viewers": set(), "seconds": 0})
    devices = defaultdict(lambda: {"events": 0, "seconds": 0})
    viewers = set()
    for row in rows:
        content = contents[row["content_id"]]
        device = devices[row["device"]]
        seconds = row["watch_duration_seconds"]
        content["seconds"] += seconds
        device["seconds"] += seconds
        device["events"] += 1
        if row["event_type"] == "PLAY":
            content["plays"] += 1
            content["viewers"].add(row["user_id"])
            viewers.add(row["user_id"])
    by_content = [
        dict(content_id=key, play_count=value["plays"], unique_viewers=len(value["viewers"]),
             total_watch_seconds=value["seconds"], total_watch_minutes=value["seconds"] / 60)
        for key, value in sorted(contents.items())
    ]
    by_device = [
        dict(device=key, event_count=value["events"], total_watch_seconds=value["seconds"],
             average_watch_seconds=value["seconds"] / value["events"])
        for key, value in sorted(devices.items())
    ]
    kpis = [
        dict(kpi_key="ALL", play_count=sum(row["play_count"] for row in by_content),
             unique_viewers=len(viewers), total_watch_seconds=sum(row["total_watch_seconds"] for row in by_content))
    ]
    return by_content, by_device, kpis


GOLD_SCHEMAS = (
    pa.schema([("content_id", pa.string()), ("play_count", pa.int64()),
               ("unique_viewers", pa.int64()), ("total_watch_seconds", pa.int64()),
               ("total_watch_minutes", pa.float64())]),
    pa.schema([("device", pa.string()), ("event_count", pa.int64()),
               ("total_watch_seconds", pa.int64()), ("average_watch_seconds", pa.float64())]),
    pa.schema([("kpi_key", pa.string()), ("play_count", pa.int64()),
               ("unique_viewers", pa.int64()), ("total_watch_seconds", pa.int64())]),
)


def publish(lake, name, rows, schema, source_snapshot):
    table = lake.create_table_if_not_exists(
        name, schema, properties={"format-version": "2", "write.format.default": "parquet"}
    )
    current = table.current_snapshot()
    key = schema.names[0]
    if current and sorted(read_rows(table, current.snapshot_id), key=lambda row: row[key]) == rows:
        return current.snapshot_id
    table.overwrite(
        pa.Table.from_pylist(rows, schema=schema),
        snapshot_properties={"source-snapshot-id": str(source_snapshot)},
    )
    table.refresh()
    current = table.current_snapshot()
    if sorted(read_rows(table, current.snapshot_id), key=lambda row: row[key]) != rows:
        raise RuntimeError(f"Snapshot read-back did not match {name}")
    return current.snapshot_id


def refresh():
    with publication_lock():
        lake = catalog()
        bronze = lake.load_table(BRONZE)
        source = bronze.current_snapshot()
        if source is None:
            raise RuntimeError("Bronze has no committed snapshot")
        rows = clean_rows(read_rows(bronze, source.snapshot_id))
        schema = bronze.schema().as_arrow()
        silver_id = publish(lake, SILVER, rows, schema, source.snapshot_id)
        data = aggregate(rows)
        snapshots = {
            name: publish(lake, name, records, schema, silver_id)
            for name, records, schema in zip(GOLD, data, GOLD_SCHEMAS, strict=True)
        }
        pending = PUBLISHED.with_suffix(".tmp")
        pending.write_text(json.dumps(snapshots, indent=2) + "\n")
        pending.replace(PUBLISHED)
        print(f"Bronze snapshot {source.snapshot_id}; Silver snapshot {silver_id}; {len(rows)} clean rows")
        for name, records in zip(GOLD, data, strict=True):
            print(f"{name}: {len(records)} rows, snapshot {snapshots[name]}")
        print(json.dumps(data[-1][0]))


def wait_catalog():
    deadline = time.monotonic() + 90
    while True:
        try:
            namespaces = catalog().list_namespaces()
            print(f"Iceberg table bucket is reachable. Namespaces: {namespaces}")
            return
        except (OSError, RESTError, RequestException):
            if time.monotonic() >= deadline:
                raise
        time.sleep(2)


def verify_bronze(event_id, wait):
    lake = catalog()
    deadline = time.monotonic() + wait
    while True:
        table = lake.load_table(BRONZE)
        snapshot = table.current_snapshot()
        if snapshot:
            scan = table.scan(row_filter=EqualTo("event_id", event_id), snapshot_id=snapshot.snapshot_id)
            rows = scan.to_arrow().to_pylist()
            if rows:
                if len(rows) != 1:
                    raise RuntimeError(f"Expected one {event_id}, found {len(rows)}")
                files = sorted(task.file.file_path for task in scan.plan_files())
                if not files or not all(path.endswith(".parquet") for path in files):
                    raise RuntimeError("Bronze scan did not resolve to Parquet")
                print(f"Iceberg v{table.metadata.format_version}; snapshot {snapshot.snapshot_id}")
                print(f"Metadata: {table.metadata_location}")
                print(f"Parquet: {', '.join(files)}")
                print(json.dumps(rows[0], default=str))
                return
        if time.monotonic() >= deadline:
            raise RuntimeError(f"{event_id} is absent from committed Bronze")
        time.sleep(2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("refresh")
    commands.add_parser("wait-catalog")
    verify = commands.add_parser("verify-bronze")
    verify.add_argument("event_id")
    verify.add_argument("--wait", type=int, default=0)
    args = parser.parse_args()
    if args.command == "refresh":
        refresh()
    elif args.command == "wait-catalog":
        wait_catalog()
    else:
        verify_bronze(args.event_id, args.wait)
