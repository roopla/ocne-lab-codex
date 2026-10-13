// Optional local UI acceptance. Uses the lab's existing Puppeteer and Edge installation.
const { createRequire } = require("node:module");
const path = require("node:path");
const live = process.argv.includes("--live-oracle");
const assert = require("node:assert/strict");
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
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  try {
    await page.setViewport({ width: 1440, height: 1120 });
    await page.goto("http://localhost:8080", { waitUntil: "networkidle0" });
    await page.waitForFunction(
      () =>
        document.querySelector("#connection").textContent ===
        "All services reachable",
    );
    assert.match(
      await page.$eval("#mode-banner", (e) => e.textContent),
      live ? /ORACLE MODE/i : /LOCAL DEMO/,
    );
    await page.type(
      "#tasks-text",
      "Verify application writes during RAC instance maintenance",
    );
    await page.click("#tasks-submit");
    await page.waitForFunction(() =>
      document.querySelector("#tasks-message").textContent.startsWith("Saved."),
    );
    // Simulate a response lost AFTER the actual HTTP write has completed.
    await page.evaluate(() => {
      const original = window.fetch.bind(window);
      let once = true;
      window.fetch = async (...args) => {
        const r = await original(...args);
        if (once && args[0] === "/api/notes" && args[1]?.method === "POST") {
          once = false;
          throw new TypeError("Simulated lost reply after commit");
        }
        return r;
      };
    });
    await page.type(
      "#notes-text",
      "Both services are ready. Next: observe the database instance during failover.",
    );
    await page.click("#notes-submit");
    await page.waitForFunction(
      () =>
        document.querySelector("#notes-submit").textContent ===
        "Retry same request",
    );
    const requestId = await page.evaluate(
      () => JSON.parse(localStorage.getItem("rac-board-notes")).id,
    );
    await page.reload({ waitUntil: "networkidle0" });
    assert.equal(await page.$eval("#notes-text", (e) => e.disabled), true);
    assert.equal(
      await page.evaluate(
        () => JSON.parse(localStorage.getItem("rac-board-notes")).id,
      ),
      requestId,
    );
    await page.click("#notes-submit");
    await page.waitForFunction(() =>
      document
        .querySelector("#notes-message")
        .textContent.startsWith("Recovered:"),
    );
    assert.equal(
      await page.evaluate(() => localStorage.getItem("rac-board-notes")),
      null,
    );
    const rows = await page.evaluate(
      async () => (await (await fetch("/api/notes")).json()).items,
    );
    assert.equal(rows.filter((r) => r.id === requestId).length, 1);
    await page.screenshot({
      path: path.join(
        lab,
        live
          ? "apps/rac-lab-board/docs/diagrams/application-live.png"
          : "apps/rac-lab-board/docs/diagrams/application-preview.png",
      ),
      fullPage: true,
    });
    await page.setViewport({ width: 390, height: 844 });
    await page.screenshot({
      path: path.join(lab, "logs/rac-app-mobile.png"),
      fullPage: true,
    });
    assert.equal(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
      true,
      "Mobile page must not overflow",
    );
    await page.type("#tasks-text", '<img src=x onerror="window.xss=1">');
    await page.click("#tasks-submit");
    await page.waitForFunction(() =>
      document.querySelector("#tasks-message").textContent.startsWith("Saved."),
    );
    assert.equal(await page.evaluate(() => window.xss), undefined);
    assert.equal(
      await page.$eval("#tasks-list", (e) => e.querySelectorAll("img").length),
      0,
    );
    assert.deepEqual(errors, []);
    console.log(
      "PASS: " +
        (live ? "live Oracle" : "local demo") +
        " desktop UI, mode banner, create task, lost-response retry across reload, one stored note, mobile width, escaped markup, no browser errors",
    );
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
