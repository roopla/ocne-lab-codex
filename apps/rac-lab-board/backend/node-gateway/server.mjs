import http from "node:http";
import { randomUUID } from "node:crypto";
const port = Number(process.env.PORT || 8081),
  host = process.env.HOST || "0.0.0.0";
const pod = process.env.POD_NAME || "gateway-local";
const upstream = {
  tasks: process.env.TASKS_URL || "http://127.0.0.1:8082",
  notes: process.env.NOTES_URL || "http://127.0.0.1:8083",
};
const timeout = Number(process.env.UPSTREAM_TIMEOUT_MS || 15000);
function send(res, status, data) {
  res.writeHead(status, {
    "content-type": "application/json",
    "cache-control": "no-store",
    "x-gateway-pod": pod,
  });
  res.end(JSON.stringify(data));
}
async function call(url, options = {}) {
  return fetch(url, { ...options, signal: AbortSignal.timeout(timeout) });
}
const server = http.createServer(async (req, res) => {
  const start = Date.now(),
    trace = randomUUID();
  res.on("finish", () =>
    console.log(
      JSON.stringify({
        service: "gateway",
        trace,
        method: req.method,
        status: res.statusCode,
        elapsedMs: Date.now() - start,
      }),
    ),
  );
  try {
    const path = new URL(req.url, "http://local").pathname;
    if (req.method === "GET" && ["/livez", "/readyz"].includes(path))
      return send(res, 200, { ok: true, pod });
    if (req.method === "GET" && path === "/api/status") {
      const entries = await Promise.all(
        Object.entries(upstream).map(async ([name, url]) => {
          try {
            const r = await call(url + "/readyz");
            return [name, { healthy: r.ok, ...(await r.json()) }];
          } catch {
            return [name, { healthy: false, error: "Service unreachable" }];
          }
        }),
      );
      return send(res, 200, {
        gateway: pod,
        services: Object.fromEntries(entries),
        checkedAt: new Date().toISOString(),
      });
    }
    const match = path.match(/^\/api\/(tasks|notes)(\/[0-9a-f-]{36})?$/i);
    if (!match) return send(res, 404, { error: "Route not found" });
    if (!["GET", "POST"].includes(req.method))
      return send(res, 405, { error: "Use GET or POST" });
    if (req.method === "POST" && match[2])
      return send(res, 405, { error: "POST only to collection" });
    // A foreign browser origin must not write through this local lab gateway.
    if (
      req.method === "POST" &&
      req.headers.origin &&
      new URL(req.headers.origin).host !== req.headers.host
    )
      return send(res, 403, { error: "Cross-origin writes are not allowed" });
    let body;
    if (req.method === "POST") {
      if (
        !String(req.headers["content-type"])
          .toLowerCase()
          .startsWith("application/json")
      )
        return send(res, 415, { error: "Use application/json" });
      const chunks = [];
      let size = 0;
      for await (const chunk of req) {
        size += chunk.length;
        if (size > 4096) {
          send(res, 413, { error: "Body exceeds 4096 bytes" });
          return;
        }
        chunks.push(chunk);
      }
      body = Buffer.concat(chunks);
    }
    const response = await call(
      upstream[match[1]] + "/" + match[1] + (match[2] || ""),
      {
        method: req.method,
        headers: {
          "content-type": "application/json",
          "x-request-trace": trace,
        },
        body,
      },
    );
    // Do not retry writes here: the database might have committed before the response was lost.
    const data = await response.json();
    data.gateway = pod;
    data.trace = trace;
    send(res, response.status, data);
  } catch {
    send(res, 503, {
      error: "Downstream unavailable",
      outcome: req.method === "POST" ? "unknown" : "unavailable",
      retrySameId: req.method === "POST",
      gateway: pod,
    });
  }
});
server.requestTimeout = 20000;
server.headersTimeout = 10000;
server.keepAliveTimeout = 5000;
server.listen(port, host, () =>
  console.log(JSON.stringify({ service: "gateway", port, pod })),
);
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 20000).unref();
  });
