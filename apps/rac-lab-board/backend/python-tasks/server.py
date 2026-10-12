"""Small append-only tasks API. Memory mode is only for local demonstrations."""

import json, os, re, signal, threading, time
from contextlib import contextmanager, nullcontext
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from concurrent.futures import ThreadPoolExecutor

UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
MODE = os.getenv("STORE_MODE", "oracle")
POD = os.getenv("POD_NAME", "tasks-local")


class Conflict(Exception):
    pass


class Invalid(Exception):
    pass


def validate(value):
    if not isinstance(value, dict) or set(value) != {"id", "text"}:
        raise Invalid("Use exactly id and text")
    if not isinstance(value["id"], str) or not UUID.fullmatch(value["id"]):
        raise Invalid("id must be a lowercase UUID")
    text = value["text"]
    if not isinstance(text, str) or not text.strip() or len(text.encode("utf-8")) > 800:
        raise Invalid("text must be nonblank and at most 800 UTF-8 bytes")
    return value["id"], text


class MemoryStore:
    def request(self):
        return nullcontext()

    def __init__(self):
        self.rows = {}
        self.lock = threading.Lock()

    def meta(self):
        return {
            "mode": "memory",
            "pod": POD,
            "instance": "DEMO (no RAC)",
            "pdb": "none",
            "service": "python-tasks",
        }

    def read(self, id=None):
        with self.lock:
            return (
                ([self.rows[id]] if id in self.rows else [])
                if id
                else sorted(
                    self.rows.values(),
                    key=lambda r: (r["createdAt"], r["id"]),
                    reverse=True,
                )[:100]
            )

    def write(self, id, text):
        with self.lock:
            if id in self.rows:
                if self.rows[id]["text"] != text:
                    raise Conflict()
                return self.rows[id], True
            row = {
                "id": id,
                "text": text,
                "createdAt": datetime.now(timezone.utc).isoformat(),
            }
            self.rows[id] = row
            return row, False

    def close(self):
        pass


class OracleStore:
    def __init__(self):
        import oracledb

        self.driver = oracledb
        self.local = threading.local()
        self.pool = oracledb.create_pool(
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASSWORD"],
            dsn=os.environ["DB_DSN"],
            min=0,
            max=2,
            increment=1,
            getmode=oracledb.POOL_GETMODE_TIMEDWAIT,
            wait_timeout=3000,
            ping_interval=0,
            ping_timeout=2000,
            timeout=60,
            max_lifetime_session=300,
        )

    @contextmanager
    def request(self):
        with self.pool.acquire() as con:
            con.call_timeout = 5000
            self.local.con = con
            try:
                yield
            finally:
                self.local.con = None

    def connection(self):
        return nullcontext(self.local.con)

    def meta(self):
        with self.connection() as con, con.cursor() as cur:
            cur.execute(
                "SELECT SYS_CONTEXT('USERENV','INSTANCE_NAME'),SYS_CONTEXT('USERENV','CON_NAME'),SYS_CONTEXT('USERENV','SERVICE_NAME') FROM dual"
            )
            instance, pdb, service = cur.fetchone()
            if pdb != os.getenv("EXPECTED_PDB", "LABPDB"):
                raise RuntimeError("Wrong PDB")
            cur.execute("SELECT id FROM board_tasks WHERE 1=0")
            return {
                "mode": "oracle",
                "pod": POD,
                "instance": instance,
                "pdb": pdb,
                "databaseService": service,
                "service": "python-tasks",
            }

    @staticmethod
    def rows(cur):
        return [{"id": r[0], "text": r[1], "createdAt": r[2]} for r in cur.fetchall()]

    def select(self, cur, id=None):
        sql = "SELECT id,body,TO_CHAR(created_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS.FF3\"Z\"') FROM board_tasks"
        if id:
            cur.execute(sql + " WHERE id=:id", id=id)
        else:
            cur.execute(
                sql + " ORDER BY created_at DESC,id DESC FETCH FIRST 100 ROWS ONLY"
            )
        return self.rows(cur)

    def read(self, id=None):
        with self.connection() as con, con.cursor() as cur:
            return self.select(cur, id)

    def write(self, id, text):
        with self.connection() as con, con.cursor() as cur:
            try:
                cur.execute(
                    "INSERT INTO board_tasks(id,body) VALUES(:id,:body)",
                    id=id,
                    body=text,
                )
                row = self.select(cur, id)[0]
                con.commit()  # Lost reply here is an unknown outcome; retry the same id.
                return row, False
            except self.driver.IntegrityError as exc:
                con.rollback()
                if exc.args[0].code != 1:
                    raise
                rows = self.select(cur, id)
                if not rows:
                    raise RuntimeError("Duplicate row unavailable")
                if rows[0]["text"] != text:
                    raise Conflict()
                return rows[0], True

    def close(self):
        self.pool.close(force=True)


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, *args):
        super().__init__(*args)
        self.executor = ThreadPoolExecutor(max_workers=8)
        self.slots = threading.BoundedSemaphore(16)

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return

        def run():
            try:
                self.process_request_thread(request, address)
            finally:
                self.slots.release()

        self.executor.submit(run)

    def server_close(self):
        super().server_close()
        self.executor.shutdown(wait=True)


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(20)

    def log_message(self, *args):
        pass

    def send(self, code, data):
        raw = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)
        print(
            json.dumps(
                {
                    "service": "python-tasks",
                    "status": code,
                    "pod": POD,
                    "trace": self.headers.get("X-Request-Trace", "")[:128],
                }
            ),
            flush=True,
        )

    def handle_api(self):
        if self.command == "GET" and self.path == "/livez":
            return self.send(200, {"ok": True, "pod": POD})
        try:
            with STORE.request():
                self.dispatch()
        except Exception as exc:
            print(
                json.dumps(
                    {
                        "service": "python-tasks",
                        "errorType": type(exc).__name__,
                        "oracleCode": (
                            getattr(exc.args[0], "full_code", None)
                            if exc.args
                            else None
                        ),
                        "trace": self.headers.get("X-Request-Trace", "")[:128],
                    }
                ),
                flush=True,
            )
            self.send(
                503,
                {
                    "error": "Database unavailable",
                    "outcome": "unknown" if self.command == "POST" else "unavailable",
                    "retrySameId": self.command == "POST",
                    "pod": POD,
                },
            )

    def dispatch(self):
        try:
            if self.command == "GET" and self.path == "/livez":
                return self.send(200, {"ok": True, "pod": POD})
            if self.command == "GET" and self.path == "/readyz":
                return self.send(200, {"ok": True, **STORE.meta()})
            id = (
                self.path.removeprefix("/tasks/")
                if self.path.startswith("/tasks/")
                else None
            )
            if self.path != "/tasks" and not (id and UUID.fullmatch(id)):
                return self.send(404, {"error": "Route not found"})
            if self.command == "GET":
                meta = STORE.meta()
                rows = STORE.read(id)
                return self.send(
                    404 if id and not rows else 200, {"items": rows, "meta": meta}
                )
            if self.command != "POST" or id:
                return self.send(405, {"error": "Use GET or POST on collection"})
            if not self.headers.get("Content-Type", "").startswith("application/json"):
                return self.send(415, {"error": "Use application/json"})
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 4096:
                return self.send(413, {"error": "Body must be 1..4096 bytes"})
            id, text = validate(json.loads(self.rfile.read(size)))
            meta = STORE.meta()
            row, duplicate = STORE.write(id, text)
            return self.send(
                200 if duplicate else 201,
                {"item": row, "deduplicated": duplicate, "meta": meta},
            )
        except Conflict:
            return self.send(409, {"error": "This id already has different text"})
        except (Invalid, ValueError, UnicodeError) as exc:
            return self.send(
                400,
                {
                    "error": (
                        str(exc)
                        if isinstance(exc, Invalid)
                        else "Invalid JSON or content length"
                    )
                },
            )
        except Exception as exc:
            print(
                json.dumps(
                    {
                        "service": "python-tasks",
                        "errorType": type(exc).__name__,
                        "oracleCode": (
                            getattr(exc.args[0], "full_code", None)
                            if exc.args
                            else None
                        ),
                        "trace": self.headers.get("X-Request-Trace", "")[:128],
                    }
                ),
                flush=True,
            )
            return self.send(
                503,
                {
                    "error": "Database unavailable",
                    "outcome": "unknown" if self.command == "POST" else "unavailable",
                    "retrySameId": self.command == "POST",
                    "pod": POD,
                },
            )

    do_GET = handle_api
    do_POST = handle_api
    do_PUT = handle_api
    do_DELETE = handle_api


if __name__ == "__main__":
    if MODE not in ("memory", "oracle"):
        raise SystemExit("STORE_MODE must be oracle or memory")
    STORE = MemoryStore() if MODE == "memory" else OracleStore()
    server = Server(
        (os.getenv("HOST", "0.0.0.0"), int(os.getenv("PORT", "8082"))), Handler
    )

    def stop(*_):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    print(json.dumps({"service": "python-tasks", "mode": MODE, "pod": POD}), flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        STORE.close()
