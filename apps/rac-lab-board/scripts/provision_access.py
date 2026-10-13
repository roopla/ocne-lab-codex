"""Explicit app schema/Secret provisioning over existing SSH; never prints credentials."""

import argparse
import base64
import json
import re
import subprocess
from prepare import APP, LAB


def credentials():
    values = {}
    for kind in ("tasks", "notes"):
        folder = LAB / "private/rac-app-secrets"
        user = (folder / (kind + "-username.txt")).read_text()
        password = (folder / (kind + "-password.txt")).read_text()
        if user != "LAB_" + kind.upper() or not re.fullmatch("[0-9a-f]{30}", password):
            raise SystemExit("Unexpected credential format; inspect protected files")
        values[kind] = (user, password)
    if values["tasks"][1] == values["notes"][1]:
        raise SystemExit("Passwords must differ")
    return values


def remote(command, payload, passwords=()):
    result = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "ocne-cp", command],
        input=payload,
        text=True,
        capture_output=True,
    )
    output = result.stdout + result.stderr
    for password in passwords:
        output = output.replace(password, "[REDACTED]")
        output = output.replace(
            base64.b64encode(password.encode()).decode(), "[REDACTED]"
        )
    print(output, end="")
    if result.returncode or re.search(r"(?:ORA-|SP2-)\d+", output):
        raise SystemExit(
            "Remote operation failed; inspect partial state before retrying"
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action", choices=("create-schemas", "create-secrets", "verify")
    )
    args = parser.parse_args()
    sql_command = "kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'ORACLE_SID=RACCDB1 /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -L -s / as sysdba'"
    if args.action == "verify":
        remote(sql_command, (APP / "database/02-verify.sql").read_text())
    else:
        values = credentials()
        passwords = [v[1] for v in values.values()]
        if args.action == "create-schemas":
            sql = (APP / "database/01-create-schemas.sql").read_text()
            sql = "\n".join(
                line for line in sql.splitlines() if not line.startswith("ACCEPT ")
            )
            for kind, (_, password) in values.items():
                sql = sql.replace("&" + kind + "_password", password)
            remote(sql_command, sql + "\n", passwords)
        else:
            check = subprocess.run(
                [
                    "ssh",
                    "-o",
                    "BatchMode=yes",
                    "ocne-cp",
                    "kubectl get namespace rac-app -o json",
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            namespace = json.loads(check.stdout)
            if (
                namespace["metadata"].get("labels", {}).get("app.kubernetes.io/part-of")
                != "rac-lab-board"
            ):
                raise SystemExit("Namespace ownership mismatch")
            for kind, (username, password) in values.items():
                obj = {
                    "apiVersion": "v1",
                    "kind": "Secret",
                    "type": "Opaque",
                    "metadata": {
                        "name": "board-" + kind + "-db",
                        "namespace": "rac-app",
                        "labels": {"app.kubernetes.io/part-of": "rac-lab-board"},
                    },
                    "data": {
                        "username": base64.b64encode(username.encode()).decode(),
                        "password": base64.b64encode(password.encode()).decode(),
                    },
                }
                remote("kubectl create -f -", json.dumps(obj), passwords)
