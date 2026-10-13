"""Opt-in HTTP workload. Writes records; never injects a fault or contacts Kubernetes."""

import argparse, json, time, uuid, urllib.request, urllib.error, sys
from datetime import datetime, timezone
from pathlib import Path


def call(url, body=None):
    req = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        r = urllib.request.urlopen(req, timeout=22)
    except urllib.error.HTTPError as e:
        r = e
    with r:
        return r.status, json.loads(r.read())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--kind", choices=["tasks", "notes"], default="tasks")
    parser.add_argument("--seconds", type=int, default=120)
    parser.add_argument("--interval", type=float, default=1)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--allow-writes", action="store_true")
    args = parser.parse_args()
    if not args.allow_writes:
        parser.error(
            "This probe creates append-only records. Add --allow-writes after deployment to opt in."
        )
    if args.seconds < 1 or args.interval < 0:
        parser.error("seconds must be positive and interval nonnegative")
    url = args.base_url.rstrip("/") + "/api/" + args.kind
    start = time.monotonic()
    run = uuid.uuid4().hex[:8]
    accepted = {}
    unresolved = {}
    counts = {
        "attempts": 0,
        "created": 0,
        "deduplicated": 0,
        "failedAttempts": 0,
        "verified": 0,
        "missingOrUnknown": 0,
    }
    sequence = 0
    pending = None
    args.out.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation prevents accidental overwriting of an earlier exercise transcript.
    with args.out.open("x", encoding="utf-8") as log:

        def emit(record):
            record = {
                "time": datetime.now(timezone.utc).isoformat(),
                "run": run,
                **record,
            }
            line = json.dumps(record)
            log.write(line + "\n")
            log.flush()
            print(line, flush=True)

        while time.monotonic() - start < args.seconds:
            if pending is None:
                sequence += 1
                pending = {
                    "id": str(uuid.uuid4()),
                    "text": f"Failover probe {run} / {sequence}",
                }
                unresolved[pending["id"]] = pending
            before = time.monotonic()
            counts["attempts"] += 1
            try:
                status, data = call(url, pending)
                emit(
                    {
                        "phase": "write",
                        "id": pending["id"],
                        "status": status,
                        "elapsedMs": round((time.monotonic() - before) * 1000),
                        "meta": data.get("meta"),
                        "gateway": data.get("gateway"),
                        "deduplicated": data.get("deduplicated"),
                    }
                )
                if status in (200, 201):
                    if (
                        data.get("item", {}).get("id") != pending["id"]
                        or data["item"]["text"] != pending["text"]
                    ):
                        raise RuntimeError("Mismatched acknowledgement")
                    counts[
                        "deduplicated" if data.get("deduplicated") else "created"
                    ] += 1
                    accepted[pending["id"]] = pending
                    unresolved.pop(pending["id"])
                    pending = None
                else:
                    counts["failedAttempts"] += 1
                    if 400 <= status < 500:
                        emit(
                            {
                                "phase": "fatal",
                                "error": "Nonretryable HTTP status; inspect before continuing",
                            }
                        )
                        break
            except (OSError, ValueError) as exc:
                counts["failedAttempts"] += 1
                emit(
                    {
                        "phase": "write",
                        "id": pending["id"],
                        "status": "network-error",
                        "errorType": type(exc).__name__,
                    }
                )
            time.sleep(args.interval)
        # Query by exact ID, not the truncated latest-100 list; include any unknown final write.
        for id, payload in {**accepted, **unresolved}.items():
            try:
                status, data = call(url + "/" + id)
                rows = data.get("items", [])
                verified = (
                    status == 200
                    and len(rows) == 1
                    and rows[0].get("text") == payload["text"]
                )
                counts["verified" if verified else "missingOrUnknown"] += 1
                emit(
                    {
                        "phase": "verify",
                        "id": id,
                        "status": status,
                        "verified": verified,
                        "previouslyAcknowledged": id in accepted,
                    }
                )
            except (OSError, ValueError) as exc:
                counts["missingOrUnknown"] += 1
                emit(
                    {
                        "phase": "verify",
                        "id": id,
                        "verified": False,
                        "errorType": type(exc).__name__,
                    }
                )
        emit(
            {
                "phase": "summary",
                **counts,
                "acknowledgedIds": len(accepted),
                "unresolvedAtWriteEnd": list(unresolved),
                "interpretation": "Verification errors need investigation; they are not proof of data loss.",
            }
        )
    return 0 if counts["attempts"] > 0 and counts["missingOrUnknown"] == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
