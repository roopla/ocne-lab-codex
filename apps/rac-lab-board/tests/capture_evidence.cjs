// Render recorded, sanitized command output for the manual. No cluster mutations.
const { createRequire } = require("node:module");
const path = require("node:path");
const fs = require("node:fs");
const lab = path.resolve(__dirname, "../../..");
const puppeteer = createRequire(
  path.join(lab, "private/diagram-tools/package.json"),
)("puppeteer");
(async () => {
  const browser = await puppeteer.launch({
    executablePath:
      process.env.BROWSER_PATH ||
      "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    headless: true,
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1320, height: 1000, deviceScaleFactor: 1 });
    for (const [file, title, subtitle, out] of [
      [
        "rac-app-status-20261013.json",
        "Application health: /api/status",
        "Actual HTTP response captured 13 October 2026. Main URL: http://localhost:8080",
        "health-response.png",
      ],
      [
        "rac-app-cluster-20261013.txt",
        "Kubernetes deployment acceptance",
        "Actual kubectl output after four application pod replacement tests. Rendered transcript, not an interactive terminal.",
        "cluster-acceptance.png",
      ],
    ]) {
      const text = fs.readFileSync(path.join(lab, "logs", file), "utf8");
      await page.setContent(
        "<!doctype html><html><head><style>body{margin:0;padding:40px;background:#edf3f3;color:#15333b;font-family:Segoe UI,Arial}h1{font-size:28px;margin:0 0 12px}p{color:#4c6871}pre{background:#102730;color:#def5ee;padding:26px;white-space:pre-wrap;overflow-wrap:anywhere;font:14px/1.55 Consolas,monospace;border-radius:12px}</style></head><body><h1></h1><p></p><pre></pre></body></html>",
      );
      await page.evaluate(
        ({ text, title, subtitle }) => {
          document.querySelector("h1").textContent = title;
          document.querySelector("p").textContent = subtitle;
          document.querySelector("pre").textContent = text;
        },
        { text, title, subtitle },
      );
      await page.screenshot({
        path: path.join(lab, "apps/rac-lab-board/docs/diagrams", out),
        fullPage: true,
      });
      console.log("Rendered recorded evidence:", out);
    }
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
