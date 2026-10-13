"""Explicit manual step: generate protected application passwords locally. Prints no secrets."""

import os, secrets, subprocess
from pathlib import Path
from prepare import LAB

if __name__ == "__main__":
    target = LAB / "private/rac-app-secrets"
    if target.exists():
        raise SystemExit(
            "Secret directory already exists; inspect and reuse, do not overwrite"
        )
    target.mkdir(mode=0o700)
    if os.name == "nt":
        identity = subprocess.check_output(["whoami"], text=True).strip()
        subprocess.run(
            [
                "icacls",
                str(target),
                "/inheritance:r",
                "/grant:r",
                identity + ":(OI)(CI)F",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
    for kind in ("tasks", "notes"):
        for suffix, value in [
            ("username", "LAB_" + kind.upper()),
            ("password", secrets.token_hex(15)),
        ]:
            file = target / (kind + "-" + suffix + ".txt")
            with file.open("x", encoding="ascii") as out:
                out.write(value)
            if os.name != "nt":
                file.chmod(0o600)
    print(
        "Created four protected files under private/rac-app-secrets. No database or Kubernetes change."
    )
