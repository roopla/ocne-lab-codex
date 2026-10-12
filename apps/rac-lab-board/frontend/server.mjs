import http from "node:http";
import { readFile } from "node:fs/promises";
const port = Number(process.env.PORT || 8080),
  host = process.env.HOST || "0.0.0.0";
const gateway = process.env.GATEWAY_URL || "http://127.0.0.1:8081";
const pod = process.env.POD_NAME || "frontend-local";
const files = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/app.js": ["app.js", "text/javascript"],
  "/style.css": ["style.css", "text/css"],
};
const server = http.createServer(async (req, res) => {
  const headers = {
    "x-frontend-pod": pod,
    "x-content-type-options": "nosniff",
    "cache-control": "no-store",
    "content-security-policy":
      "default-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
  };
  try {
    const path = new URL(req.url, "http://local").pathname;
    if (path === "/livez" || path === "/readyz") {
      res.writeHead(200, { ...headers, "content-type": "application/json" });
      return res.end(JSON.stringify({ ok: true, pod }));
    }
    if (path.startsWith("/api/")) {
      if (
        req.method === "POST" &&
        req.headers.origin &&
        new URL(req.headers.origin).host !== req.headers.host
      ) {
        res.writeHead(403, { ...headers, "content-type": "application/json" });
        return res.end(
          JSON.stringify({ error: "Cross-origin writes are not allowed" }),
        );
      }
      if (!["GET", "POST"].includes(req.method)) {
        res.writeHead(405, headers);
        return res.end();
      }
      const chunks = [];
      let length = 0;
      for await (const c of req) {
        length += c.length;
        if (length > 4096) {
          res.writeHead(413, headers);
          return res.end();
        }
        chunks.push(c);
      }
      const response = await fetch(gateway + path, {
        method: req.method,
        headers: {
          "content-type": req.headers["content-type"] || "application/json",
        },
        body: req.method === "POST" ? Buffer.concat(chunks) : undefined,
        signal: AbortSignal.timeout(18000),
      });
      res.writeHead(response.status, {
        ...headers,
        "content-type": "application/json",
      });
      return res.end(await response.text());
    }
    if (req.method !== "GET" || !files[path]) {
      res.writeHead(404, headers);
      return res.end("Not found");
    }
    const [name, type] = files[path];
    res.writeHead(200, { ...headers, "content-type": type });
    res.end(await readFile(new URL("./public/" + name, import.meta.url)));
  } catch {
    res.writeHead(503, { ...headers, "content-type": "application/json" });
    res.end(
      JSON.stringify({
        error: "Gateway unavailable",
        outcome: req.method === "POST" ? "unknown" : "unavailable",
        retrySameId: req.method === "POST",
      }),
    );
  }
});
server.requestTimeout = 22000;
server.headersTimeout = 10000;
server.listen(port, host, () =>
  console.log(JSON.stringify({ service: "frontend", port, pod })),
);
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 24000).unref();
  });
