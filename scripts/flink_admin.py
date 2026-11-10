"""Check the Flink REST API and resolve local recovery metadata."""
import argparse
import json
from pathlib import Path
import re
import sys
import time
from urllib.request import urlopen

URL = "http://flink-jobmanager:8081"
STATE = Path("/app/.runtime/flink-state")
TERMINAL = {"FINISHED", "FAILED", "CANCELED", "SUSPENDED"}


def get(path):
    with urlopen(URL + path, timeout=4) as response:
        return json.load(response)


def wait_ready():
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        try:
            if get("/overview")["slots-total"] > 0:
                return
        except OSError:
            pass
        time.sleep(2)
    sys.exit("Flink TaskManager did not register a slot")


def restore(job_id):
    savepoints = sorted(
        (STATE / "savepoints").glob(f"savepoint-{job_id[:6]}-*/_metadata"),
        key=lambda path: path.stat().st_mtime_ns,
    )
    if savepoints:
        state = savepoints[-1].parent
    else:
        checkpoints = [path.parent for path in (STATE / "checkpoints" / job_id).glob("chk-*/_metadata")]
        if not checkpoints:
            sys.exit("Previous job has no durable state. Investigate before restarting to avoid replay.")
        state = max(checkpoints, key=lambda path: int(path.name.split("-")[1]))
    print("file:///opt/flink/pipeline-state/" + str(state.relative_to(STATE)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("wait", "jobs", "checkpoints", "restore"))
    parser.add_argument("job_id", nargs="?")
    args = parser.parse_args()
    if args.command in {"checkpoints", "restore"} and not re.fullmatch(r"[a-f0-9]{32}", args.job_id or ""):
        parser.error("expected a 32-character Flink job ID")
    if args.command == "wait":
        wait_ready()
    elif args.command == "jobs":
        for job in get("/jobs/overview")["jobs"]:
            if job["state"] not in TERMINAL:
                print(job["jid"], job["name"], job["state"])
    elif args.command == "checkpoints":
        status = get(f"/jobs/{args.job_id}/checkpoints")
        print(json.dumps({key: status[key] for key in ("counts", "latest")}))
    else:
        restore(args.job_id)
