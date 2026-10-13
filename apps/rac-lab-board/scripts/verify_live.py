"""Live Oracle acceptance: writes one row per language, retries it, and checks conflicts."""

import argparse
import json
import sys
import uuid
from concurrent.futures import ThreadPoolExecutor
from load_probe import call

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--allow-writes", action="store_true")
    args = parser.parse_args()
    if not args.allow_writes:
        parser.error("Add --allow-writes to create two acceptance records")
    for kind in ("tasks", "notes"):
        url = args.base_url.rstrip("/") + "/api/" + kind
        payload = {"id": str(uuid.uuid4()), "text": "Live Oracle acceptance: " + kind}
        status, body = call(url, payload)
        assert status == 201 and body["item"]["id"] == payload["id"], (status, body)
        assert (
            body["meta"]["mode"] == "oracle" and body["meta"]["pdb"] == "LABPDB"
        ), body
        with ThreadPoolExecutor(max_workers=4) as pool:
            retries = list(pool.map(lambda _: call(url, payload), range(4)))
        assert all(
            code == 200 and reply["deduplicated"] for code, reply in retries
        ), retries
        conflict, _ = call(url, {**payload, "text": "Different text with same ID"})
        assert conflict == 409, conflict
        fetched, rows = call(url + "/" + payload["id"])
        assert (
            fetched == 200
            and len(rows["items"]) == 1
            and rows["items"][0]["text"] == payload["text"]
        ), rows
        print(
            json.dumps(
                {
                    "kind": kind,
                    "id": payload["id"],
                    "create": status,
                    "concurrentRetryStatuses": [r[0] for r in retries],
                    "conflict": conflict,
                    "exactIdRows": len(rows["items"]),
                    "meta": body["meta"],
                    "retryInstances": sorted(
                        {r[1]["meta"]["instance"] for r in retries}
                    ),
                }
            ),
            flush=True,
        )
    print(
        "PASS: both Oracle backends create, concurrently deduplicate, reject conflicts and return exactly one matching row"
    )
