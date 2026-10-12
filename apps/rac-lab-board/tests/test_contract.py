"""Real HTTP tests of all four processes in MEMORY mode. No Oracle or Kubernetes writes."""

import concurrent.futures, json, sys, unittest, urllib.request, urllib.error, uuid, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import dev

BASE = "http://127.0.0.1:18080"


def request(path, body=None, headers=None, method=None):
    raw = (
        None
        if body is None
        else (body if isinstance(body, bytes) else json.dumps(body).encode())
    )
    req = urllib.request.Request(
        BASE + path,
        data=raw,
        headers=headers or {"Content-Type": "application/json"},
        method=method,
    )
    try:
        r = urllib.request.urlopen(req, timeout=24)
    except urllib.error.HTTPError as e:
        r = e
    with r:
        content = r.read()
        return r.status, json.loads(content) if content else {}, dict(r.headers)


class Contracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.children = dev.start(18080)

    @classmethod
    def tearDownClass(cls):
        dev.stop(cls.children)

    def test_01_health_and_mode(self):
        code, data, _ = request("/api/status")
        self.assertEqual(code, 200)
        for name in ("tasks", "notes"):
            self.assertTrue(data["services"][name]["healthy"])
            self.assertEqual(data["services"][name]["mode"], "memory")

    def test_02_create_read_trace(self):
        for kind in ("tasks", "notes"):
            with self.subTest(service=kind):
                payload = {"id": str(uuid.uuid4()), "text": "Contract test"}
                code, data, h = request("/api/" + kind, payload)
                self.assertEqual(code, 201)
                self.assertFalse(data["deduplicated"])
                self.assertEqual(data["item"]["id"], payload["id"])
                self.assertEqual(data["meta"]["mode"], "memory")
                self.assertEqual(data["gateway"], "gateway-local")
                self.assertIn("x-frontend-pod", {k.lower(): v for k, v in h.items()})
                code, data, _ = request("/api/" + kind + "/" + payload["id"])
                self.assertEqual(code, 200)
                self.assertEqual(data["items"][0]["text"], payload["text"])

    def test_03_lost_response_retry_same_id(self):
        for kind in ("tasks", "notes"):
            payload = {
                "id": str(uuid.uuid4()),
                "text": "Pretend the first committed response was lost",
            }
            request("/api/" + kind, payload)  # Client deliberately discards the result.
            code, data, _ = request("/api/" + kind, payload)
            self.assertEqual(code, 200)
            self.assertTrue(data["deduplicated"])
            _, data, _ = request("/api/" + kind + "/" + payload["id"])
            self.assertEqual(len(data["items"]), 1)

    def test_04_conflicting_id(self):
        for kind in ("tasks", "notes"):
            payload = {"id": str(uuid.uuid4()), "text": "Original"}
            request("/api/" + kind, payload)
            code, _, _ = request("/api/" + kind, {**payload, "text": "Changed"})
            self.assertEqual(code, 409)
            _, data, _ = request("/api/" + kind + "/" + payload["id"])
            self.assertEqual(data["items"][0]["text"], "Original")

    def test_05_concurrent_retries(self):
        for kind in ("tasks", "notes"):
            payload = {"id": str(uuid.uuid4()), "text": "Concurrent idempotency"}
            with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
                results = list(
                    pool.map(lambda _: request("/api/" + kind, payload)[0], range(8))
                )
            self.assertEqual(results.count(201), 1)
            self.assertEqual(results.count(200), 7)

    def test_06_invalid_input(self):
        cases = [
            {},
            [],
            {"id": "bad", "text": "test"},
            {"id": str(uuid.uuid4()), "text": " "},
            {"id": str(uuid.uuid4()), "text": 2},
            {"id": str(uuid.uuid4()), "text": "x" * 801},
            {"id": str(uuid.uuid4()), "text": "x", "extra": True},
            b"{invalid}",
            b"{'id':'00000000-0000-0000-0000-000000000001','text':'not strict JSON'}",
            b'{"id":"00000000-0000-0000-0000-000000000001","text":"x"} trailing',
        ]
        for kind in ("tasks", "notes"):
            for payload in cases:
                with self.subTest(kind=kind, payloadType=type(payload).__name__):
                    self.assertEqual(request("/api/" + kind, payload)[0], 400)

    def test_07_utf8_byte_limit(self):
        for kind in ("tasks", "notes"):
            self.assertEqual(
                request(
                    "/api/" + kind, {"id": str(uuid.uuid4()), "text": "\u20ac" * 267}
                )[0],
                400,
            )
            self.assertEqual(
                request(
                    "/api/" + kind, {"id": str(uuid.uuid4()), "text": "\u20ac" * 266}
                )[0],
                201,
            )

    def test_08_body_limit(self):
        self.assertEqual(request("/api/tasks", b"x" * 5000)[0], 413)

    def test_09_methods_routes_and_missing_id(self):
        self.assertEqual(request("/api/anything")[0], 404)
        for kind in ("tasks", "notes"):
            self.assertEqual(request("/api/" + kind + "/" + str(uuid.uuid4()))[0], 404)
            self.assertEqual(request("/api/" + kind, method="DELETE")[0], 405)

    def test_10_origin_guard(self):
        self.assertEqual(
            request(
                "/api/tasks",
                {"id": str(uuid.uuid4()), "text": "test"},
                headers={
                    "Content-Type": "application/json",
                    "Origin": "https://foreign.invalid",
                },
            )[0],
            403,
        )
        self.assertEqual(
            request(
                "/api/tasks",
                {"id": str(uuid.uuid4()), "text": "same origin"},
                headers={"Content-Type": "application/json", "Origin": BASE},
            )[0],
            201,
        )

    def test_11_markup_is_data(self):
        text = "<script>window.pwned=true</script> ' OR 1=1 --"
        for kind in ("tasks", "notes"):
            code, data, _ = request(
                "/api/" + kind, {"id": str(uuid.uuid4()), "text": text}
            )
            self.assertEqual(code, 201)
            self.assertEqual(data["item"]["text"], text)

    def test_12_no_password_in_status(self):
        _, data, _ = request("/api/status")
        self.assertNotIn("password", json.dumps(data).lower())

    def test_13_bounded_list(self):
        for kind in ("tasks", "notes"):
            for i in range(101):
                self.assertEqual(
                    request(
                        "/api/" + kind,
                        {"id": str(uuid.uuid4()), "text": f"Bounded list {i}"},
                    )[0],
                    201,
                )
            _, data, _ = request("/api/" + kind)
            self.assertEqual(len(data["items"]), 100)

    def test_90_backend_loss_is_isolated(self):
        process = next(p for name, p, _ in self.children if name == "tasks")
        process.terminate()
        process.wait(timeout=10)
        code, data, _ = request("/api/status")
        self.assertEqual(code, 200)
        self.assertFalse(data["services"]["tasks"]["healthy"])
        self.assertTrue(data["services"]["notes"]["healthy"])
        code, data, _ = request(
            "/api/tasks", {"id": str(uuid.uuid4()), "text": "Unknown result"}
        )
        self.assertEqual(code, 503)
        self.assertTrue(data["retrySameId"])
        self.assertEqual(data["outcome"], "unknown")
        self.assertEqual(request("/api/notes")[0], 200)
        self.assertEqual(request("/livez")[0], 200)

    def test_91_gateway_loss_is_reported(self):
        process = next(p for name, p, _ in self.children if name == "gateway")
        process.terminate()
        process.wait(timeout=10)
        code, data, _ = request(
            "/api/notes", {"id": str(uuid.uuid4()), "text": "Unknown result"}
        )
        self.assertEqual(code, 503)
        self.assertTrue(data["retrySameId"])
        self.assertEqual(request("/livez")[0], 200)


if __name__ == "__main__":
    unittest.main(verbosity=2)
