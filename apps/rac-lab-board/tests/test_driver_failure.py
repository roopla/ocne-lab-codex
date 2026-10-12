"""Actual Oracle drivers against a deliberately non-listening LOCAL socket. No RAC access."""

import os, socket, subprocess, sys, time, unittest, urllib.request, urllib.error, json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from prepare import APP, LAB, java_tool, python_bin, compile_java


class DriverFailure(unittest.TestCase):
    def test_drivers_start_without_database_and_keep_liveness(self):
        compile_java()
        # Reserve an unused loopback port without listening; no Oracle server can be reached.
        with socket.socket() as closed:
            closed.bind(("127.0.0.1", 0))
            dbport = closed.getsockname()[1]
            dsn = f"(DESCRIPTION=(CONNECT_TIMEOUT=1)(RETRY_COUNT=0)(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT={dbport}))(CONNECT_DATA=(SERVICE_NAME=NO_DATABASE)))"
            java = APP / "backend/java-notes"
            for kind, port, command in [
                (
                    "tasks",
                    18182,
                    [str(python_bin()), str(APP / "backend/python-tasks/server.py")],
                ),
                (
                    "notes",
                    18183,
                    [
                        java_tool("java"),
                        "-Xmx128m",
                        "-cp",
                        str(java / "build") + os.pathsep + str(java / "lib/*"),
                        "NotesServer",
                    ],
                ),
            ]:
                with self.subTest(service=kind), (
                    LAB / "logs" / f"rac-app-driver-failure-{kind}.log"
                ).open("wb") as log:
                    env = {
                        **os.environ,
                        "STORE_MODE": "oracle",
                        "DB_USER": "DUMMY_TEST_USER",
                        "DB_PASSWORD": "DUMMY_NOT_A_SECRET",
                        "DB_DSN": dsn,
                        "HOST": "127.0.0.1",
                        "PORT": str(port),
                    }
                    p = subprocess.Popen(
                        command,
                        env=env,
                        stdout=log,
                        stderr=subprocess.STDOUT,
                        creationflags=(
                            subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
                        ),
                    )

                    def request(path, body=None):
                        req = urllib.request.Request(
                            f"http://127.0.0.1:{port}" + path,
                            data=None if body is None else json.dumps(body).encode(),
                            headers={"Content-Type": "application/json"},
                        )
                        try:
                            r = urllib.request.urlopen(req, timeout=15)
                        except urllib.error.HTTPError as e:
                            r = e
                        with r:
                            return r.status, json.loads(r.read())

                    try:
                        for _ in range(100):
                            if p.poll() is not None:
                                self.fail(
                                    "Driver process failed startup; inspect local driver log"
                                )
                            try:
                                if request("/livez")[0] == 200:
                                    break
                            except OSError:
                                time.sleep(0.1)
                        else:
                            self.fail("Driver process never became live")
                        self.assertEqual(request("/readyz")[0], 503)
                        status, data = request(
                            "/" + kind,
                            {
                                "id": "00000000-0000-0000-0000-000000000001",
                                "text": "Local failure test",
                            },
                        )
                        self.assertEqual(status, 503)
                        self.assertTrue(data["retrySameId"])
                        self.assertEqual(data["outcome"], "unknown")
                        self.assertNotIn("DUMMY_NOT_A_SECRET", json.dumps(data))
                        self.assertEqual(request("/livez")[0], 200)
                    finally:
                        p.terminate()
                        try:
                            p.wait(timeout=15)
                        except subprocess.TimeoutExpired:
                            p.kill()
                            p.wait()


if __name__ == "__main__":
    unittest.main(verbosity=2)
