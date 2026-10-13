"""Build/export containers with Docker or rootless Podman; does not deploy."""

import argparse, subprocess
from pathlib import Path
from prepare import APP, LAB
import hashlib, json

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", default="1.0.0")
    parser.add_argument("--engine", choices=("docker", "podman"), default="docker")
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    if args.archive and args.archive.exists():
        raise SystemExit("Refusing to rebuild into an existing image archive; choose a new version")
    subprocess.run([args.engine, "info"], check=True, stdout=subprocess.DEVNULL)
    service = APP / "backend/java-notes"
    for item in json.loads((service / "dependencies.lock.json").read_text()):
        p = service / "lib" / item["name"]
        if (
            not p.exists()
            or hashlib.sha256(p.read_bytes()).hexdigest() != item["sha256"]
        ):
            raise SystemExit(
                "Run scripts/prepare.py first; Java dependency missing or mismatched"
            )
    images = []
    for name, folder in [
        ("frontend", "frontend"),
        ("gateway", "backend/node-gateway"),
        ("tasks", "backend/python-tasks"),
        ("notes", "backend/java-notes"),
    ]:
        image = f"localhost/rac-board-{name}:{args.tag}"
        images.append(image)
        subprocess.run(
            [
                args.engine,
                "build",
                "--platform",
                "linux/amd64",
                *(
                    ["--pull=always", "--memory=1024m"]
                    if args.engine == "podman"
                    else ["--pull"]
                ),
                "-t",
                image,
                str(APP / folder),
            ],
            check=True,
        )
    if args.archive:
        if args.archive.exists():
            raise SystemExit("Refusing to overwrite an existing image archive")
        args.archive.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                args.engine,
                "save",
                *(
                    ["--multi-image-archive", "--format=docker-archive"]
                    if args.engine == "podman"
                    else []
                ),
                "-o",
                str(args.archive),
                *images,
            ],
            check=True,
        )
    print("Built " + ", ".join(images) + ". No deployment performed.")
