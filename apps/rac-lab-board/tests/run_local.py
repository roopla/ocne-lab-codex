"""Run local acceptance and save reproducible output; no RAC/cluster access."""

import datetime, json, subprocess, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import dev
from prepare import APP, LAB

stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
report = []


def run(args):
    print("Running: " + " ".join(args), flush=True)
    result = subprocess.run(
        args,
        cwd=APP,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    report.append(
        "$ "
        + " ".join(args)
        + "\n"
        + result.stdout
        + "\nExit code: "
        + str(result.returncode)
        + "\n"
    )
    if result.returncode:
        raise RuntimeError(result.stdout)
    print(result.stdout, flush=True)


try:
    run([sys.executable, "tests/test_contract.py"])
    run([sys.executable, "tests/test_oracle_transaction.py"])
    run([sys.executable, "tests/test_driver_failure.py"])
    for path in [
        "frontend/server.mjs",
        "frontend/public/app.js",
        "backend/node-gateway/server.mjs",
    ]:
        run(["node", "--check", path])
    children = dev.start(8080)
    try:
        run(["node", "tests/browser.cjs"])
        for kind in ["tasks", "notes"]:
            outfile = LAB / "logs" / f"rac-app-local-probe-{stamp}-{kind}.jsonl"
            run(
                [
                    sys.executable,
                    "scripts/load_probe.py",
                    "--kind",
                    kind,
                    "--seconds",
                    "2",
                    "--interval",
                    "0.4",
                    "--allow-writes",
                    "--out",
                    str(outfile),
                ]
            )
    finally:
        dev.stop(children)
finally:
    text = (
        "Local acceptance UTC "
        + stamp
        + "\nAll service data stores are temporary local memory. Driver failure test uses only a closed loopback socket. No RAC or Kubernetes actions.\n\n"
        + "\n".join(report)
    )
    (LAB / "logs" / f"rac-app-validation-{stamp}.txt").write_text(
        text, encoding="utf-8"
    )
    (LAB / "logs/rac-app-validation-latest.txt").write_text(text, encoding="utf-8")
print(
    "All local checks passed and temporary application processes were stopped.",
    flush=True,
)
