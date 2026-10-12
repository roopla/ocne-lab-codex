"""Start four LOCAL memory-mode processes; never opens a RAC connection."""

import argparse, os, socket, subprocess, sys, time
from datetime import datetime, timezone
from pathlib import Path
from prepare import APP, LAB, java_tool, python_bin, compile_java


def start(base=8080):
    for port in range(base, base + 4):
        with socket.socket() as sock:
            try:
                sock.bind(("127.0.0.1", port))
            except OSError:
                raise RuntimeError(
                    f"Local port {port} is already in use; select another --base-port"
                )
    compile_java()
    node = "node"
    service = APP / "backend/java-notes"
    commands = [
        (
            "tasks",
            [str(python_bin()), str(APP / "backend/python-tasks/server.py")],
            base + 2,
        ),
        (
            "notes",
            [
                java_tool("java"),
                "-Xms32m",
                "-Xmx128m",
                "-Dsun.net.httpserver.maxReqTime=20",
                "-Dsun.net.httpserver.maxRspTime=20",
                "-cp",
                str(service / "build") + os.pathsep + str(service / "lib/*"),
                "NotesServer",
            ],
            base + 3,
        ),
        ("gateway", [node, str(APP / "backend/node-gateway/server.mjs")], base + 1),
        ("frontend", [node, str(APP / "frontend/server.mjs")], base),
    ]
    children = []
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    (LAB / "logs").mkdir(exist_ok=True)
    try:
        for name, command, port in commands:
            env = {
                **os.environ,
                "STORE_MODE": "memory",
                "HOST": "127.0.0.1",
                "PORT": str(port),
                "POD_NAME": name + "-local",
                "GATEWAY_URL": f"http://127.0.0.1:{base+1}",
                "TASKS_URL": f"http://127.0.0.1:{base+2}",
                "NOTES_URL": f"http://127.0.0.1:{base+3}",
            }
            for key in ("DB_USER", "DB_PASSWORD", "DB_DSN"):
                env.pop(key, None)
            log = (LAB / "logs" / f"rac-app-{stamp}-{name}.log").open("wb")
            process = subprocess.Popen(
                command,
                env=env,
                stdout=log,
                stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            children.append((name, process, log))
        import urllib.request

        for _, process, _ in children:
            if process.poll() is not None:
                raise RuntimeError("A service exited; inspect logs/")
        for port in range(base, base + 4):
            for attempt in range(100):
                try:
                    with urllib.request.urlopen(
                        f"http://127.0.0.1:{port}/livez", timeout=1
                    ) as r:
                        if r.status == 200:
                            break
                except OSError:
                    time.sleep(0.1)
            else:
                raise RuntimeError(f"Port {port} did not become live; inspect logs/")
        return children
    except BaseException:
        stop(children)
        raise


def stop(children):
    for _, process, _ in reversed(children):
        if process.poll() is None:
            process.terminate()
    for _, process, log in children:
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        log.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-port", type=int, default=8080)
    parser.add_argument("--seconds", type=int, default=0)
    args = parser.parse_args()
    children = start(args.base_port)
    print(
        f"LOCAL DEMO ONLY: http://localhost:{args.base_port} (no RAC). Ctrl+C stops these four processes.",
        flush=True,
    )
    begin = time.monotonic()
    try:
        while not args.seconds or time.monotonic() - begin < args.seconds:
            if any(p.poll() is not None for _, p, _ in children):
                raise RuntimeError("A service exited; inspect logs/")
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        stop(children)
