"""Fetch checksum-locked Java jars, prepare a local Python venv, compile Java. No deployment."""

import hashlib, json, os, shutil, subprocess, sys, urllib.request, venv
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
LAB = APP.parents[1]


def java_home():
    if os.getenv("JAVA_HOME"):
        return Path(os.environ["JAVA_HOME"])
    binary = shutil.which("javac")
    if binary:
        return Path(binary).resolve().parents[1]
    found = sorted((LAB / "private/app-tools").glob("jdk*/bin/javac.exe"))
    if found:
        return found[-1].parents[1]
    raise SystemExit("Install JDK 21 or set JAVA_HOME. See docs/LOCAL-DEVELOPMENT.md.")


def java_tool(name):
    return str(java_home() / "bin" / (name + (".exe" if os.name == "nt" else "")))


def python_bin():
    return (
        LAB
        / "private/rac-app-venv"
        / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    )


def compile_java():
    service = APP / "backend/java-notes"
    (service / "build").mkdir(exist_ok=True)
    subprocess.run(
        [
            java_tool("javac"),
            "--release",
            "21",
            "-cp",
            str(service / "lib/*"),
            "-d",
            str(service / "build"),
            str(service / "src/NotesServer.java"),
        ],
        check=True,
    )


if __name__ == "__main__":
    service = APP / "backend/java-notes"
    (service / "lib").mkdir(exist_ok=True)
    for item in json.loads((service / "dependencies.lock.json").read_text()):
        target = service / "lib" / item["name"]
        if not target.exists():
            target.write_bytes(urllib.request.urlopen(item["url"], timeout=60).read())
        if hashlib.sha256(target.read_bytes()).hexdigest() != item["sha256"]:
            raise SystemExit("Checksum mismatch: " + item["name"])
        print("Verified " + item["name"], flush=True)
    target = python_bin()
    if not target.exists():
        venv.create(target.parents[1], with_pip=True)
    requirements = APP / "backend/python-tasks/requirements.lock.txt"
    if not requirements.exists():
        requirements = APP / "backend/python-tasks/requirements.txt"
    subprocess.run(
        [
            str(target),
            "-m",
            "pip",
            "install",
            "--disable-pip-version-check",
            "-r",
            str(requirements),
        ],
        check=True,
    )
    compile_java()
    print("Local dependencies and Java compilation ready. No cluster changes.")
