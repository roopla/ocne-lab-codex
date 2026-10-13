"""Package explicit app build inputs only. Excludes secrets and compiled output."""

import tarfile
from prepare import APP, LAB

if __name__ == "__main__":
    archive = LAB / "private/rac-app-source-1.0.0.tar.gz"
    if archive.exists():
        raise SystemExit("Archive already exists; reuse it or choose a new version")
    with tarfile.open(archive, "x:gz") as out:
        for root in ("frontend", "backend", "scripts"):
            for file in sorted((APP / root).rglob("*")):
                if file.is_file() and not any(
                    p in file.parts for p in ("__pycache__", "node_modules", "build")
                ):
                    if file.suffix in (".pem", ".key", ".p12") or file.name.startswith(
                        ".env"
                    ):
                        raise SystemExit(
                            "Unexpected private input; inspect " + str(file)
                        )
                    out.add(file, arcname=file.relative_to(APP).as_posix())
    print("Packaged build inputs:", archive)
