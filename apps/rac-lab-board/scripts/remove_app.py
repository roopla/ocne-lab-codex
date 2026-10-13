"""Run on the kubectl workstation. Plan by default; remove exact app objects only."""

import argparse
import json
import subprocess

NS = "rac-app"
OWNER = "rac-lab-board"


def get(kind, name):
    result = subprocess.run(
        ["kubectl", "-n", NS, "get", kind, name, "--ignore-not-found", "-o", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout) if result.stdout.strip() else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument(
        "--remove-secrets",
        action="store_true",
        help="Also remove the two app Secrets; database passwords/data remain unchanged",
    )
    args = parser.parse_args()
    namespace = get("namespace", NS)
    if namespace is None:
        print("rac-app namespace absent; nothing to remove")
        return
    if (
        namespace["metadata"].get("labels", {}).get("app.kubernetes.io/part-of")
        != OWNER
    ):
        raise SystemExit("Namespace ownership mismatch; no changes")
    targets = [
        (kind, "board-" + tier)
        for kind in ("deployment", "service", "poddisruptionbudget")
        for tier in ("frontend", "gateway", "tasks", "notes")
    ]
    targets.append(("configmap", "rac-board-config"))
    if args.remove_secrets:
        targets += [("secret", "board-tasks-db"), ("secret", "board-notes-db")]
    planned = []
    for kind, name in targets:
        obj = get(kind, name)
        if obj is None:
            continue
        if obj["metadata"].get("labels", {}).get("app.kubernetes.io/part-of") != OWNER:
            raise SystemExit(
                "Ownership mismatch for " + kind + "/" + name + "; no changes"
            )
        planned.append((kind, name, obj["metadata"]["uid"]))
    print(
        "Context:",
        subprocess.check_output(
            ["kubectl", "config", "current-context"], text=True
        ).strip(),
    )
    for kind, name, _ in planned:
        print(("DELETE " if args.execute else "PLAN ") + NS + ":" + kind + "/" + name)
    print(
        "Preserving namespace, all Oracle schemas/data, RAC resources, volumes, images and VMs."
    )
    if not args.execute:
        print("No changes. Add --execute only when ready to uninstall the application.")
        return
    for kind, name, uid in planned:
        current = get(kind, name)
        if current is None:
            continue
        if current["metadata"]["uid"] != uid:
            raise SystemExit(
                "Object replaced since plan; stopped before deleting " + name
            )
        subprocess.run(
            [
                "kubectl",
                "-n",
                NS,
                "delete",
                kind,
                name,
                "--wait=true",
                "--timeout=120s",
            ],
            check=True,
        )
    print(
        "Requested app objects removed. Retained database data can be reused on redeployment."
    )


if __name__ == "__main__":
    main()
