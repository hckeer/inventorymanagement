# Phase 1 — Lightbenders MCP Server

Bridge between the iPad scanner web app and ERPNext warehouse inventory. Implements [implementationerp.md](../implementationerp.md) Phase 1 tools with API keys kept server-side only.

## Skills used

| Layer | Skill | Purpose |
|---|---|---|
| MCP server scaffold | [typescript-mcp-server-generator](https://skills.sh/github/awesome-copilot/typescript-mcp-server-generator) | TypeScript MCP + Express structure |
| ERPNext API | [erpnext (Membrane)](https://skills.sh/membranedev/application-skills/erpnext) | DocTypes from Phase 0 (`Warehouse Container`, `Equipment Assembly`) |
| Assembly expansion | `lightbenders_warehouse/services/expand_assembly.py` | Same logic ported to `src/lib/expand_assembly.ts` |

## Prerequisites

Phase 0 Frappe app installed and pilot seed run on ERPNext:

```bash
bench --site erp.<domain> execute lightbenders_warehouse.setup.seed_pilot.seed_all
```

Create an ERPNext **API key + secret** (User → API Access) with Stock Manager permissions.

## Environment

Copy `.env.example` and set on the VPS:

```bash
ERPNEXT_URL=https://erp.<your-domain>
ERPNEXT_API_KEY=...
ERPNEXT_API_SECRET=...
ERPNEXT_COMPANY=Lightbenders          # optional if Global Defaults set
MCP_API_KEY=...                        # optional — required header for scanner-web
PORT=3001
```

## Run

```bash
cd mcp-server
npm install
npm run dev          # HTTP API for scanner-web (Phase 2)
npm run build && npm start

# MCP stdio mode (Claude Desktop / agents)
ERPNEXT_URL=... ERPNEXT_API_KEY=... ERPNEXT_API_SECRET=... npm run dev -- --stdio
```

Health check (§0.N3):

```bash
curl http://localhost:3001/health
```

## HTTP API (scanner-web calls these)

| Endpoint | Body | Purpose |
|---|---|---|
| `POST /api/audit_container` | `{ "container_barcode": "TRAY-004" }` | Mode 1 — quick audit |
| `POST /api/start_session` | `{ "mode": "dispatch", "source_barcode": "CART-012", "destination_barcode": "TRUCK-1" }` | Open dispatch/return session |
| `POST /api/scan_serial` | `{ "session_id": "...", "serial": "LB-CS-ARM-001" }` | Add scanned serial |
| `POST /api/end_session` | `{ "session_id": "..." }` | Reconcile vs expected |
| `POST /api/confirm_session` | `{ "session_id": "...", "proceed_anyway": true, "reason": "..." }` | Material Transfer + Stock Entry |

If `MCP_API_KEY` is set, pass header `X-Api-Key: <value>`.

### Audit response shape

```json
{
  "label": "Light Tray 04",
  "container_barcode": "TRAY-004",
  "warehouse": "Rack Tray 04 - LB",
  "expected": [{ "item_code": "ARRI-LAMP-HEAD", "qty": 4 }],
  "actual": { "ARRI-LAMP-HEAD": 4 },
  "missing": [{ "item_code": "ARRI-DIFFUSER", "expected": 4, "actual": 3, "delta": 1 }],
  "surplus": [],
  "not_tracked_v1": [{ "item_code": "SANDBAG-25LB", "qty": 8, "tracking": "qty_only" }]
}
```

## MCP tools (stdio)

Same operations registered as MCP tools: `audit_container`, `start_session`, `scan_serial`, `end_session`, `confirm_session`.

## File map

```
mcp-server/
├── src/
│   ├── index.ts                 # HTTP server entry
│   ├── mcp.ts                   # MCP stdio tools
│   ├── app.ts                   # routes + service wiring
│   ├── lib/
│   │   ├── erpnext_client.ts    # §1.1 ERPNext REST client
│   │   ├── expand_assembly.ts   # §1.2 assembly expansion
│   │   ├── resolve_expected.ts  # load config → expand
│   │   ├── diff.ts              # expected vs actual / scanned
│   │   └── sessions.ts          # in-memory scan sessions (V1)
│   └── tools/
│       ├── audit_container.ts
│       ├── start_session.ts
│       ├── scan_serial.ts
│       ├── end_session.ts
│       └── confirm_session.ts
└── test/warehouse.test.ts
```

## Tests

```bash
npm test
```

Unit tests cover `expand_assembly` (mirrors Python), audit diff, and session reconcile logic without ERPNext.

## Phase 0 validation unlock

After deploy with ERPNext credentials:

```bash
curl -X POST http://localhost:3001/api/audit_container \
  -H 'Content-Type: application/json' \
  -d '{"container_barcode":"TRAY-004"}'
```

This unlocks checklist items **0.5b–0.5g** when combined with dispatch/return session flows.

## Next: Phase 2

`scanner-web/` — Audit / Dispatch / Return UI calling this server over HTTPS.
