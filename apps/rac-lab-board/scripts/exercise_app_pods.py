"""Replace one pod of each app tier, sequentially, while both Oracle APIs receive writes."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import time
from prepare import APP, LAB


def ssh(command):
    return subprocess.check_output(
        ["ssh", "-o", "BatchMode=yes", "ocne-cp", command], text=True
    )


def rac_identity():
    data = json.loads(ssh("kubectl -n rac get pod racnode1-0 racnode2-0 -o json"))
    return {
        p["metadata"]["name"]: {
            "uid": p["metadata"]["uid"],
            "restarts": [c["restartCount"] for c in p["status"]["containerStatuses"]],
        }
        for p in data["items"]
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-pod-replacement", action="store_true")
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    args = parser.parse_args()
    if not args.allow_pod_replacement:
        parser.error(
            "Explicit --allow-pod-replacement is required; also writes test records"
        )
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = LAB / "logs" / ("rac-app-pod-exercises-" + stamp)
    output.mkdir()
    baseline_rac = rac_identity()
    results = []
    for tier in ("frontend", "gateway", "tasks", "notes"):
        name = "board-" + tier
        ssh("kubectl -n rac-app rollout status deployment/" + name + " --timeout=120s")
        command = (
            "kubectl -n rac-app get pods -l app.kubernetes.io/name=" + name + " -o json"
        )
        before = json.loads(ssh(command))["items"]
        assert len(before) == 2 and all(
            p["status"]["containerStatuses"][0]["ready"] for p in before
        ), "Healthy two-replica baseline required"
        victim = sorted(before, key=lambda p: p["metadata"]["name"])[0]
        assert (
            victim["metadata"]["labels"]["app.kubernetes.io/part-of"] == "rac-lab-board"
        )
        processes = []
        for kind in ("tasks", "notes"):
            log = output / (tier + "-" + kind + ".jsonl")
            proc = subprocess.Popen(
                [
                    sys.executable,
                    str(APP / "scripts/load_probe.py"),
                    "--kind",
                    kind,
                    "--base-url",
                    args.base_url,
                    "--seconds",
                    "20",
                    "--interval",
                    "0.5",
                    "--allow-writes",
                    "--out",
                    str(log),
                ],
                stdout=subprocess.DEVNULL,
            )
            processes.append((proc, log))
        time.sleep(3)
        deletion = (
            "kubectl -n rac-app delete pod "
            + victim["metadata"]["name"]
            + " --wait=true --timeout=120s"
        )
        start = time.monotonic()
        deleted = ssh(deletion)
        rolled = ssh(
            "kubectl -n rac-app rollout status deployment/" + name + " --timeout=120s"
        )
        elapsed = round(time.monotonic() - start, 2)
        after = json.loads(ssh(command))["items"]
        assert victim["metadata"]["uid"] not in [p["metadata"]["uid"] for p in after]
        assert len(after) == 2 and all(
            p["status"]["containerStatuses"][0]["ready"] for p in after
        )
        summaries = {}
        for proc, log in processes:
            rc = proc.wait(timeout=180)
            records = [json.loads(line) for line in log.read_text().splitlines()]
            summaries[log.stem] = records[-1]
            assert rc == 0 and records[-1]["missingOrUnknown"] == 0, summaries
        assert (
            rac_identity() == baseline_rac
        ), "RAC pod identity/restart count changed; inspect before continuing"
        result = {
            "tier": tier,
            "command": deletion,
            "output": deleted.strip() + "\n" + rolled.strip(),
            "oldUid": victim["metadata"]["uid"],
            "readyPodsAfter": [
                {
                    "name": p["metadata"]["name"],
                    "uid": p["metadata"]["uid"],
                    "node": p["spec"]["nodeName"],
                }
                for p in after
            ],
            "deleteAndRolloutSeconds": elapsed,
            "probes": summaries,
        }
        results.append(result)
        (output / "results.json").write_text(
            json.dumps({"racBefore": baseline_rac, "results": results}, indent=2)
        )
        print(json.dumps(result), flush=True)
    print(
        "PASS: four sequential app-pod replacements; all recorded IDs verified; RAC pods unchanged. Evidence:",
        output,
    )
