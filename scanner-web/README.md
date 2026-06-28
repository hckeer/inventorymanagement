# Phase 2 — Scanner web app

iPad-friendly warehouse scan UI for Lightbenders. Calls **MCP server only** — no ERPNext keys in the browser.

## Prerequisites

1. ERPNext running locally (this bench uses **port 8080**, not 8000)
2. MCP server running with `.env` pointed at ERPNext:

```bash
cd ../mcp-server
npm install
npm run dev    # http://localhost:3001
```

## Run

```bash
cd scanner-web
npm install
npm run dev    # http://localhost:5173 — open on iPad via LAN IP
```

Set `VITE_MCP_URL` in `.env` if MCP is on another host (VPS deploy).

## Modes

| Mode | Flow |
|---|---|
| **Audit** | Scan container only → quantity check vs config |
| **Dispatch** | Scan source cart → scan truck → scan every serial → confirm Stock Entry |
| **Return** | Scan truck first → scan destination cart → scan every serial → confirm |

## HID barcode gun

Gun is paired as a Bluetooth keyboard. Focus stays on the scan field; each scan sends Enter and clears for the next item.

## Under-packed sessions

If items are missing at **Finish scanning**:

- **Go back and scan** — continue scanning
- **Confirm transfer** → **Proceed anyway** — optional reason → Stock Entry still created

## Phase 2 checklist (implementationerp.md)

```
[x] 2.1  Audit / Dispatch / Return mode toggle
[x] 2.2  HID continuous scan (Enter clears input)
[x] 2.3  Chat UI + MCP client + not_tracked_v1 grey bubbles
[x] 2.4  Proceed-anyway confirmation + reason
[x] 2.5  Return mode: truck → container scan order in prompts
```

## Build for deploy

```bash
npm run build
# serve dist/ behind https://scan.<domain>
```
