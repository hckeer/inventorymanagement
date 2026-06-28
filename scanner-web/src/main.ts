import {
  auditContainer,
  checkHealth,
  confirmSession,
  endSession,
  scanSerial,
  startSession,
  type AuditResult,
  type SessionEndResult,
} from "./mcp_client.js";
import {
  initialState,
  resetSession,
  stepPrompt,
  type AppState,
  type ChatMessage,
  type ScanMode,
} from "./state.js";
import "./styles.css";

let state = initialState();
let messages: ChatMessage[] = [];
let messageCounter = 0;

const app = document.querySelector<HTMLDivElement>("#app");

function uid(): string {
  messageCounter += 1;
  return `msg-${messageCounter}`;
}

function pushMessage(tone: ChatMessage["tone"], text: string, detail?: string): void {
  messages.push({ id: uid(), tone, text, detail });
  renderChat();
}

function formatGapList(
  missing: Array<{ item_code: string; delta: number }>,
  prefix: string,
): string {
  if (missing.length === 0) return "";
  return `${prefix}: ${missing.map((gap) => `${gap.delta}× ${gap.item_code}`).join(", ")}`;
}

function renderAuditResult(result: AuditResult): void {
  const gaps = [
    ...result.missing.map((gap) => `Missing ${gap.delta}× ${gap.item_code}`),
    ...result.surplus.map((gap) => `Extra ${gap.delta}× ${gap.item_code}`),
  ];

  if (gaps.length === 0) {
    pushMessage("ok", `${result.label} — all good`, "Counts match what should be on this container.");
  } else {
    pushMessage("warn", `${result.label} — needs attention`, gaps.join("\n"));
  }

  for (const line of result.not_tracked_v1) {
    pushMessage(
      "muted",
      `${line.qty}× ${line.item_code}`,
      "Not tracked in V1 — informational only",
    );
  }
}

function renderEndResult(result: SessionEndResult): void {
  if (result.complete) {
    pushMessage("ok", "Session complete", `${result.scanned.length} items scanned — ready to confirm.`);
    return;
  }

  const parts = [
    formatGapList(result.missing, "Under-packed"),
    result.unexpected.length > 0
      ? `Unexpected: ${result.unexpected.map((entry) => entry.serial).join(", ")}`
      : "",
  ].filter(Boolean);

  pushMessage("warn", "Gaps found", parts.join("\n"));
}

function renderModeButtons(): string {
  const modes: ScanMode[] = ["audit", "dispatch", "return"];
  return modes
    .map((mode) => {
      const active = state.mode === mode ? "active" : "";
      const label = mode === "audit" ? "Audit" : mode === "dispatch" ? "Dispatch" : "Return";
      return `<button type="button" class="mode-btn ${active}" data-mode="${mode}">${label}</button>`;
    })
    .join("");
}

function renderActions(): void {
  const actionBar = document.querySelector<HTMLDivElement>("#action-bar");
  if (!actionBar) return;

  if (state.mode === "audit") {
    actionBar.innerHTML = "";
    return;
  }

  if (state.step === "scan_items") {
    actionBar.innerHTML = `
      <button type="button" class="action-btn secondary" id="btn-reset">Start over</button>
      <button type="button" class="action-btn" id="btn-end">Finish scanning</button>
    `;
    actionBar.querySelector("#btn-reset")?.addEventListener("click", () => {
      state = resetSession(state);
      messages = [];
      pushMessage("system", "Session cleared");
      render();
    });
    actionBar.querySelector("#btn-end")?.addEventListener("click", () => void handleEndSession());
    return;
  }

  if (state.step === "review" && state.endResult) {
    actionBar.innerHTML = `
      <button type="button" class="action-btn secondary" id="btn-back">Go back and scan</button>
      <button type="button" class="action-btn" id="btn-confirm">Confirm transfer</button>
    `;
    actionBar.querySelector("#btn-back")?.addEventListener("click", () => {
      state = { ...state, step: "scan_items", endResult: null };
      pushMessage("system", "Keep scanning — tap Finish when done");
      render();
      focusScanInput();
    });
    actionBar.querySelector("#btn-confirm")?.addEventListener("click", () => {
      if (state.endResult?.complete) {
        void handleConfirm(false);
      } else {
        showProceedModal();
      }
    });
    return;
  }

  if (state.step === "done") {
    actionBar.innerHTML = `<button type="button" class="action-btn" id="btn-new">New session</button>`;
    actionBar.querySelector("#btn-new")?.addEventListener("click", () => {
      state = resetSession(state);
      messages = [];
      pushMessage("system", "Ready for next job");
      render();
    });
    return;
  }

  actionBar.innerHTML = `<button type="button" class="action-btn secondary" id="btn-reset">Reset</button>`;
  actionBar.querySelector("#btn-reset")?.addEventListener("click", () => {
    state = resetSession(state);
    messages = [];
    pushMessage("system", "Reset");
    render();
  });
}

function renderChat(): void {
  const chatLog = document.querySelector<HTMLDivElement>("#chat-log");
  if (!chatLog) return;
  chatLog.innerHTML = messages
    .map(
      (message) => `
      <article class="bubble bubble-${message.tone}">
        <p class="bubble-text">${escapeHtml(message.text)}</p>
        ${message.detail ? `<p class="bubble-detail">${escapeHtml(message.detail)}</p>` : ""}
      </article>
    `,
    )
    .join("");
  chatLog.scrollTop = chatLog.scrollHeight;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\n", "<br />");
}

function renderShell(): void {
  if (!app) return;

  app.innerHTML = `
    <header class="top-bar">
      <div>
        <p class="eyebrow">Lightbenders warehouse</p>
        <h1>Scan</h1>
      </div>
      <p class="status-dot" id="status">Connecting…</p>
    </header>

    <section class="mode-row" id="mode-row">
      ${renderModeButtons()}
    </section>

    <main class="chat-panel" id="chat-log" aria-live="polite"></main>

    <footer class="scan-dock">
      <p class="prompt" id="prompt">${escapeHtml(stepPrompt(state))}</p>
      <form id="scan-form" class="scan-form">
        <input
          id="scan-input"
          name="barcode"
          type="text"
          inputmode="none"
          autocomplete="off"
          autocorrect="off"
          autocapitalize="characters"
          spellcheck="false"
          placeholder="Scan here…"
          ${state.busy ? "disabled" : ""}
        />
      </form>
      <div class="action-bar" id="action-bar"></div>
    </footer>

    <div class="modal-root" id="modal-root"></div>
  `;

  bindShellEvents();
  renderChat();
  renderActions();
  focusScanInput();
}

function bindShellEvents(): void {
  document.querySelectorAll<HTMLButtonElement>(".mode-btn").forEach((button) => {
    button.addEventListener("click", () => {
      const mode = button.dataset.mode as ScanMode;
      state = resetSession({ ...state, mode });
      messages = [];
      pushMessage(
        "system",
        mode === "audit"
          ? "Audit mode — scan a container only"
          : mode === "dispatch"
            ? "Dispatch — cart to truck, scan every serial"
            : "Return — truck to cart, scan every serial",
      );
      render();
    });
  });

  document.querySelector("#scan-form")?.addEventListener("submit", (event) => {
    event.preventDefault();
    const input = document.querySelector<HTMLInputElement>("#scan-input");
    const value = input?.value.trim() ?? "";
    if (!value || state.busy) return;
    input!.value = "";
    void handleScan(value);
  });
}

function render(): void {
  renderShell();
  const promptEl = document.querySelector<HTMLParagraphElement>("#prompt");
  if (promptEl) {
    promptEl.textContent = stepPrompt(state);
  }
}

function focusScanInput(): void {
  requestAnimationFrame(() => {
    document.querySelector<HTMLInputElement>("#scan-input")?.focus();
  });
}

async function handleScan(barcode: string): Promise<void> {
  state = { ...state, busy: true };
  render();

  try {
    if (state.mode === "audit") {
      pushMessage("system", `Scanning ${barcode}…`);
      const result = await auditContainer(barcode);
      renderAuditResult(result);
    } else {
      await handleSessionScan(barcode);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "Something went wrong";
    pushMessage("error", message);
  } finally {
    state = { ...state, busy: false };
    render();
    focusScanInput();
  }
}

async function handleSessionScan(barcode: string): Promise<void> {
  const mode = state.mode;
  if (mode !== "dispatch" && mode !== "return") {
    return;
  }

  if (state.step === "scan_source") {
    state = { ...state, sourceBarcode: barcode };
    pushMessage("ok", `Source: ${barcode}`);
    state = { ...state, step: "scan_destination" };
    render();
    return;
  }

  if (state.step === "scan_destination") {
    const sourceBarcode = state.sourceBarcode;
    if (!sourceBarcode) {
      pushMessage("error", "Scan the source first");
      return;
    }

    state = { ...state, destinationBarcode: barcode };
    pushMessage("ok", `Destination: ${barcode}`);

    const started = await startSession({
      mode,
      source_barcode: sourceBarcode,
      destination_barcode: barcode,
    });

    state = {
      ...state,
      sessionId: started.session_id,
      step: "scan_items",
      scannedCount: 0,
    };

    pushMessage(
      "system",
      `${started.source_label} → ${started.destination_label}`,
      `${started.expected_audited.length} item types expected`,
    );

    for (const line of started.not_tracked_v1) {
      pushMessage("muted", `${line.qty}× ${line.item_code}`, "Not tracked in V1");
    }
    render();
    return;
  }

  if (state.step === "scan_items") {
    const sessionId = state.sessionId;
    if (!sessionId) {
      pushMessage("error", "Session not started — scan source and destination first");
      return;
    }

    const result = await scanSerial(sessionId, barcode);
    if (result.duplicate) {
      pushMessage("warn", `${barcode} already scanned`);
    } else {
      state = { ...state, scannedCount: result.scanned_count };
      pushMessage("ok", barcode, result.item_code);
    }
    render();
    return;
  }

  pushMessage("error", "Tap Finish scanning or reset the session");
}

async function handleEndSession(): Promise<void> {
  const sessionId = state.sessionId;
  if (!sessionId) return;
  state = { ...state, busy: true };
  render();

  try {
    const result = await endSession(sessionId);
    state = { ...state, endResult: result, step: "review" };
    renderEndResult(result);
    render();
  } catch (error) {
    pushMessage("error", error instanceof Error ? error.message : "Could not end session");
  } finally {
    state = { ...state, busy: false };
    render();
  }
}

function showProceedModal(): void {
  const modalRoot = document.querySelector<HTMLDivElement>("#modal-root");
  if (!modalRoot || !state.endResult) return;

  const missingText = state.endResult.missing
    .map((gap) => `${gap.delta}× ${gap.item_code}`)
    .join(", ");

  modalRoot.innerHTML = `
    <div class="modal-backdrop">
      <div class="modal" role="dialog" aria-modal="true">
        <h2>Proceed anyway?</h2>
        <p class="modal-copy">${missingText ? `Missing ${missingText}.` : "Unexpected items were scanned."} Load anyway?</p>
        <label class="modal-label" for="reason">Reason (optional)</label>
        <textarea id="reason" rows="3" placeholder="e.g. arm left on truck intentionally"></textarea>
        <div class="modal-actions">
          <button type="button" class="action-btn secondary" id="modal-cancel">Go back</button>
          <button type="button" class="action-btn warn" id="modal-proceed">Proceed anyway</button>
        </div>
      </div>
    </div>
  `;

  modalRoot.querySelector("#modal-cancel")?.addEventListener("click", () => {
    modalRoot.innerHTML = "";
    focusScanInput();
  });

  modalRoot.querySelector("#modal-proceed")?.addEventListener("click", () => {
    const reason = (modalRoot.querySelector("#reason") as HTMLTextAreaElement).value.trim();
    modalRoot.innerHTML = "";
    void handleConfirm(true, reason || undefined);
  });
}

async function handleConfirm(proceedAnyway: boolean, reason?: string): Promise<void> {
  const sessionId = state.sessionId;
  if (!sessionId) return;
  state = { ...state, busy: true };
  render();

  try {
    const result = await confirmSession(sessionId, proceedAnyway, reason);
    pushMessage(
      "ok",
      "Transfer recorded",
      `Stock entry ${result.stock_entry_id} — ${result.items_moved.reduce((sum, row) => sum + row.qty, 0)} items moved`,
    );
    state = { ...state, step: "done" };
    render();
  } catch (error) {
    pushMessage("error", error instanceof Error ? error.message : "Confirm failed");
  } finally {
    state = { ...state, busy: false };
    render();
    focusScanInput();
  }
}

async function boot(): Promise<void> {
  renderShell();
  const healthy = await checkHealth();
  const status = document.querySelector<HTMLParagraphElement>("#status");
  if (status) {
    status.textContent = healthy ? "Connected" : "MCP offline";
    status.classList.toggle("online", healthy);
  }

  if (healthy) {
    pushMessage("system", "Ready — point the gun at the scan field");
  } else {
    pushMessage(
      "error",
      "Cannot reach MCP server",
      "Start mcp-server on port 3001 and refresh",
    );
  }
  render();
}

boot();

document.addEventListener("visibilitychange", () => {
  if (!document.hidden) focusScanInput();
});

document.addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  if (target.closest(".modal-backdrop, .action-btn, .mode-btn")) return;
  focusScanInput();
});
