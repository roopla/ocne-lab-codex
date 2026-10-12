const kinds = ["tasks", "notes"];
const byId = (id) => document.getElementById(id);
const pending = {};
let refreshing = false;
function loadPending(kind) {
  try {
    return JSON.parse(localStorage.getItem("rac-board-" + kind));
  } catch {
    return null;
  }
}
function savePending(kind, value) {
  pending[kind] = value;
  try {
    if (value) localStorage.setItem("rac-board-" + kind, JSON.stringify(value));
    else localStorage.removeItem("rac-board-" + kind);
  } catch {
    /* The current page still retains the ID. */
  }
}
async function api(path, body) {
  const r = await fetch("/api/" + path, {
    method: body ? "POST" : "GET",
    headers: { "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(20000),
  });
  const data = await r.json();
  if (!r.ok) {
    const error = new Error(data.error || "Request unavailable");
    error.status = r.status;
    error.data = data;
    throw error;
  }
  return data;
}
function displayRoute(kind, data) {
  const m = data.meta || {};
  byId(kind + "-route").textContent =
    `${data.gateway || "gateway"} \u2192 ${m.pod || "?"} \u2192 ${m.instance || "?"} / ${m.pdb || "?"}${data.deduplicated ? " \u00b7 same request recovered" : ""}`;
}
async function list(kind) {
  try {
    const data = await api(kind);
    const target = byId(kind + "-list");
    target.replaceChildren();
    for (const row of data.items) {
      const li = document.createElement("li"),
        text = document.createElement("p"),
        detail = document.createElement("small");
      text.textContent = row.text;
      detail.textContent = `${new Date(row.createdAt).toLocaleString()} \u00b7 ${row.id.slice(0, 8)}`;
      li.append(text, detail);
      target.append(li);
    }
    if (!data.items.length) {
      const li = document.createElement("li");
      li.className = "empty";
      li.textContent = "No entries yet. Create your first one above.";
      target.append(li);
    }
    displayRoute(kind, data);
  } catch {
    byId(kind + "-route").textContent =
      "Service unavailable. Displaying the last successful result.";
  }
}
async function refresh() {
  if (refreshing) return;
  refreshing = true;
  try {
    const result = await api("status");
    byId("gateway-pod").textContent = result.gateway;
    let healthy = true,
      memory = false,
      allOracle = true;
    for (const kind of kinds) {
      const s = result.services[kind];
      healthy &&= s.healthy;
      memory ||= s.mode === "memory";
      allOracle &&= s.mode === "oracle";
      byId(kind + "-health").textContent = s.healthy ? "Ready" : "Unavailable";
      byId(kind + "-health").className = "health" + (s.healthy ? " ready" : "");
    }
    byId("connection").textContent = healthy
      ? "All services reachable"
      : "A service needs attention";
    byId("connection-dot").className = "dot" + (healthy ? " ready" : "");
    byId("checked").textContent =
      "Checked " + new Date(result.checkedAt).toLocaleTimeString();
    byId("mode-banner").textContent = memory
      ? "LOCAL DEMO \u00b7 No RAC connection. Records live in each process\u2019s memory and disappear when it stops. This does not test database failover."
      : allOracle
        ? "ORACLE MODE \u00b7 Requests use LABPDB. Follow the failover runbook and keep the same request ID when retrying a write."
        : "A backend is unavailable. Its storage mode and database health cannot be confirmed.";
    byId("mode-banner").className = "banner" + (allOracle ? " oracle" : "");
    await Promise.all(kinds.map(list));
  } catch {
    byId("connection").textContent = "Gateway unavailable";
    byId("connection-dot").className = "dot";
    byId("checked").textContent = "Retrying in 10 seconds";
  } finally {
    refreshing = false;
  }
}
for (const kind of kinds) {
  const textarea = byId(kind + "-text"),
    button = byId(kind + "-submit"),
    message = byId(kind + "-message");
  const restored = loadPending(kind);
  if (
    restored &&
    typeof restored.id === "string" &&
    typeof restored.text === "string"
  ) {
    pending[kind] = restored;
    textarea.value = restored.text;
    textarea.disabled = true;
    button.textContent = "Retry same request";
    message.textContent =
      "An unresolved write is saved in this browser. Retry with its original ID.";
  }
  byId(kind + "-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    if (button.disabled) return;
    if (!pending[kind]) {
      if (
        !textarea.value.trim() ||
        new TextEncoder().encode(textarea.value).length > 800
      ) {
        message.textContent = "Enter nonblank text, at most 800 UTF-8 bytes.";
        return;
      }
      savePending(kind, { id: crypto.randomUUID(), text: textarea.value });
    }
    button.disabled = true;
    textarea.disabled = true;
    message.textContent =
      "Saving request " + pending[kind].id.slice(0, 8) + "...";
    try {
      const data = await api(kind, pending[kind]);
      displayRoute(kind, data);
      savePending(kind, null);
      textarea.value = "";
      textarea.disabled = false;
      message.textContent = data.deduplicated
        ? "Recovered: the original write already exists. No duplicate created."
        : "Saved. Request ID: " + data.item.id;
      button.textContent =
        kind === "tasks" ? "Add task \u2197" : "Save note \u2197";
      await list(kind);
    } catch (error) {
      if (error.status >= 400 && error.status < 500) {
        message.textContent =
          error.message + " (request ID: " + pending[kind].id + ")";
        savePending(kind, null);
        textarea.disabled = false;
        button.textContent =
          kind === "tasks" ? "Add task \u2197" : "Save note \u2197";
      } else {
        message.textContent =
          "Response lost or service unavailable. Outcome is unknown. Retry the same request; its ID and text are saved in this browser.";
        button.textContent = "Retry same request";
      }
    } finally {
      button.disabled = false;
    }
  });
}
byId("refresh").addEventListener("click", refresh);
fetch("/readyz")
  .then((r) => r.json())
  .then((d) => (byId("frontend-pod").textContent = d.pod))
  .catch(() => {});
refresh();
setInterval(refresh, 10000);
