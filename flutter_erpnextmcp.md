# Flutter ↔ ERPNext Unification Plan

> **Status:** PLANNING — no implementation code yet  
> **Created:** 2026-06-27 · **Revised:** 2026-06-27 (greenfield go-live)  
> **Supersedes:** `implementationerp.md` Phase 4 “No V1 changes” for Flutter  
> **Related:** [implementationerp.md](./implementationerp.md) · [plan.md](./plan.md) · [mcp-server/README.md](./mcp-server/README.md)

---

## Executive summary

Unify the Flutter inventory/rental app with **ERPNext as the single ledger**. Flutter and `scanner-web` both talk to **`mcp-server` only** — never ERPNext directly. **Greenfield:** ERPNext is Day 1 production — no legacy migration. The existing Supabase-backed Flutter prototype is rewired to MCP, then Supabase is removed.

**Reliability principle:** Every layer has an assigned [skills.sh](https://skills.sh/) skill, explicit API contracts, and phase gates. No layer ships without verification.

---

## Stakeholder decisions (all locked)

### Strategic

| # | Topic | Decision |
|---|---|---|
| S1 | Scope | **Full unification** — equipment, clients, rentals in ERPNext |
| S2 | Auth | **ERPNext user login** via MCP (not Supabase Auth) |
| S3 | Warehouse UI | **Both** — `scanner-web` for iPad gun now; Flutter warehouse tab in U5 |

### Design (formerly open — resolved 2026-06-27)

| # | Topic | Decision |
|---|---|---|
| D1 | Rentable unit UI | **Hybrid** — Item list in office; drill into Serial Nos; **rental picker uses serial-level + qty lines** |
| D2 | Rental DocType | **Custom `Equipment Rental`** in Frappe (not Sales Order) |
| D3 | Go-live model | **Greenfield** — ERPNext production go-live = start of operations. **No cutover date, no rental history import, no archive.** |
| D4 | Session model | **MCP JWT + server-side ERPNext session** (Flutter never sees ERPNext `sid` or service keys) |
| D5 | Expendables | **Include qty items** in rental UI (sandbags, etc.) alongside serialized lines |

### Greenfield context (locked 2026-06-27)

| Item | Decision |
|---|---|
| Legacy systems | **None** — ERPNext is the company's first inventory/rental system |
| Cutover / migration date | **Not applicable** |
| Pre-go-live rental history | **None** — nothing to import or archive |
| Supabase role today | **Dev prototype only** — replace backend wiring; discard data, not migrate it |
| Production start | **ERPNext go-live date** = first day of real operations (seed pilot → production data entry) |

---

## Goal

One inventory truth in ERPNext. Flutter becomes a **thin client** over a **versioned MCP API**. Warehouse crew keeps `scanner-web` until Flutter warehouse UX is proven.

---

## Current state (verified in repo)

| System | State |
|---|---|
| Flutter `lib/` | 45 Dart files; Supabase repos; camera `ScannerScreen` (not MCP) |
| ERPNext | Local `:8080`; pilot Items, Serials, Containers (`TRAY-004`, `CART-012`) |
| MCP | `:3001`; warehouse endpoints working; no auth/CRUD for Flutter yet |
| scanner-web | `:5173`; audit/dispatch/return → MCP |
| Supabase | `supabase/schema.sql` — **prototype only**, not production history |

---

## Target architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Flutter (office → full ERPNext client)                          │
│  • ERPNext username/password login                               │
│  • Items (hybrid) / Customers / Rentals / Dashboard              │
│  • (U5) Warehouse audit/dispatch/return                          │
└────────────────────────────┬─────────────────────────────────────┘
                             │ HTTPS  Authorization: Bearer <jwt>
                             │ Base: /api/v1/...
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│  mcp-server/  — single integration surface                       │
│  Session store: JWT ↔ ERPNext sid (server-side only)             │
│  Service account: ERPNEXT_API_KEY for seed/system jobs only       │
└────────────────────────────┬─────────────────────────────────────┘
                             │ Cookie sid per user OR service token
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│  ERPNext + lightbenders_warehouse Frappe app                     │
│  Item · Serial No · Customer · Equipment Rental (NEW)            │
│  Warehouse Container · Equipment Assembly · Stock Entry          │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  scanner-web/  — same MCP warehouse routes (unchanged until U5)  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  Supabase  — prototype only → remove from Flutter (Phase U4)     │
└──────────────────────────────────────────────────────────────────┘
```

---

## Hybrid inventory model (D1)

### Office equipment browse

| UI level | ERPNext source | Shows |
|---|---|---|
| **Item list** | `Item` | Name, group, daily rate, serial count, qty on hand |
| **Item detail** | `Item` + child lists | Metadata + **Serial No** list + **qty stock** (non-serial items) |

### Rental builder (D1 + D5)

Two line types on **`Equipment Rental Item`** child table:

| `line_type` | Fields | Availability rule |
|---|---|---|
| `serialized` | `serial_no`, `item_code`, `daily_rate_snapshot` | Serial not on another **Active** rental; optional warehouse check |
| `qty` | `item_code`, `qty`, `daily_rate_snapshot` | `qty` ≤ available stock in default rental warehouse (ERPNext Bin / stock balance) |

**UI:** Serialized lines added via scan or serial picker; qty lines via item search + quantity stepper.

This aligns office rentals with warehouse reality (barcode = Serial No) while supporting sandbags/expendables.

---

## Custom `Equipment Rental` DocType (D2)

Extend `lightbenders_warehouse` Frappe app.

### Header — `Equipment Rental`

| Field | Type | Notes |
|---|---|---|
| `naming_series` | Select | e.g. `RENT-.YYYY.-` |
| `customer` | Link → Customer | Was Supabase `client_id` |
| `start_date` / `end_date` | Date | Inclusive rental days (match Flutter) |
| `status` | Select | `Draft` · `Active` · `Returned` · `Cancelled` · `Overdue` |
| `deposit_amount` | Currency | |
| `deposit_paid` | Check | |
| `notes` | Small Text | |
| `created_by` | Link → User | ERPNext user |

### Child — `Equipment Rental Item`

| Field | Type | Notes |
|---|---|---|
| `line_type` | Select | `serialized` \| `qty` |
| `item_code` | Link → Item | Required |
| `serial_no` | Link → Serial No | Required if `line_type=serialized` |
| `qty` | Float | Required if `line_type=qty`; default 1 for serialized |
| `daily_rate_snapshot` | Currency | Locked at submit |
| `damage_notes` | Small Text | V1 parity with Supabase |

### Server-side rules (reliability-critical)

| Rule | Implementation |
|---|---|
| No double-booked serial | Validation on submit: serial not on another Active rental overlapping dates |
| Qty availability | On submit: requested qty ≤ stock at `rental_warehouse` (configure in Stock Settings or app config) |
| Atomic submit | Single doc submit — replaces Supabase `create_rental` RPC |
| Return | Method `return_rental` on doc: status → Returned; release serials; restore qty reservation |
| Overdue | Scheduled job or MCP dashboard query: `end_date < today` AND status Active |

**Customer customize:** add `id_document` field on Customer (Supabase parity).

---

## Auth model (D4) — JWT + server-side ERPNext session

Flutter **never** receives `ERPNEXT_API_KEY`, `ERPNEXT_API_SECRET`, or raw ERPNext `sid`.

### Login flow

```
Flutter  POST /api/v1/auth/login  { username, password }
    → MCP  POST /api/method/login  (ERPNext)
    → MCP stores { sid, user_id, roles, expires_at } in session store (Redis or in-memory dev)
    → MCP returns { access_token, expires_in, user: { name, email, roles } }
         access_token = signed JWT (HS256, MCP_JWT_SECRET)

Flutter  stores access_token in flutter_secure_storage

Flutter  GET /api/v1/items  Authorization: Bearer <access_token>
    → MCP validates JWT → loads sid → forwards ERPNext API with Cookie: sid=...
    → On ERPNext 403/session expired: 401 + code SESSION_EXPIRED → Flutter re-login
```

### MCP session store requirements

| Concern | Spec |
|---|---|
| TTL | Match ERPNext session timeout; JWT `exp` ≤ sid expiry |
| Logout | Delete sid from store; JWT invalidated |
| Refresh | `POST /api/v1/auth/refresh` if sid still valid (optional U1.1) |
| Production | **Redis** session store (not in-memory) — required for U6 |

### Role mapping (document before U1)

| ERPNext role | App capability |
|---|---|
| System Manager | Full CRUD |
| Stock Manager | Items, rentals, warehouse |
| Stock User | Read + rental create/return |
| Sales User | Customers + rentals (TBD — confirm with stakeholder) |

---

## MCP API specification (reliability)

### Versioning

All Flutter routes under **`/api/v1/`**. Breaking changes → `/api/v2/`. Warehouse routes migrated to v1 prefix for consistency (keep `/api/audit_container` aliases deprecated one release).

### Response envelope

```json
{
  "ok": true,
  "data": { },
  "error": null
}
```

Errors:

```json
{
  "ok": false,
  "error": {
    "code": "SERIAL_ALREADY_RENTED",
    "message": "LB-LAMP-0001 is on active rental RENT-2026-00042",
    "details": { }
  }
}
```

**Stable error codes** (Flutter maps to human strings via existing `error_handler.dart` pattern):

| Code | HTTP | When |
|---|---|---|
| `SESSION_EXPIRED` | 401 | ERPNext sid dead |
| `FORBIDDEN` | 403 | Role insufficient |
| `NOT_FOUND` | 404 | Item/customer/rental missing |
| `SERIAL_ALREADY_RENTED` | 409 | Double-book |
| `INSUFFICIENT_QTY` | 409 | Qty line exceeds stock |
| `VALIDATION_ERROR` | 422 | Bad input |
| `ERPNEXT_UNAVAILABLE` | 502 | Upstream failure |

### Idempotency

| Endpoint | Key |
|---|---|
| `POST /api/v1/rentals` | Optional header `Idempotency-Key` — MCP dedupes draft creation |
| `POST .../submit` | Doc name idempotent; second submit returns existing state |

### Contract artifact

Before U1 coding: add `mcp-server/openapi.yaml` (or `docs/api-v1.md`) generated from route list — **single source of truth** for Flutter + MCP.

---

## MCP endpoints (full surface)

### Auth

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/auth/login` | Login |
| POST | `/api/v1/auth/logout` | Logout |
| GET | `/api/v1/auth/me` | Current user |
| POST | `/api/v1/auth/refresh` | Optional refresh |

### Items & inventory

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/items` | List Items (+ filters: group, has_serial) |
| GET | `/api/v1/items/:item_code` | Detail + serial summary + qty on hand |
| GET | `/api/v1/items/:item_code/serials` | Serial list for hybrid drill-down |
| GET | `/api/v1/serials/:serial` | Serial detail + warehouse + rental history |
| POST | `/api/v1/items` | Create Item (admin) |
| PATCH | `/api/v1/items/:item_code` | Update Item |
| POST | `/api/v1/serials` | Create Serial No |

### Customers

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/customers` | List |
| GET | `/api/v1/customers/:name` | Detail |
| POST | `/api/v1/customers` | Create |
| PATCH | `/api/v1/customers/:name` | Update |

### Rentals

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/rentals` | List (status, customer filters) |
| GET | `/api/v1/rentals/:name` | Detail + lines (serialized + qty) |
| POST | `/api/v1/rentals` | Create **Draft** with lines |
| PATCH | `/api/v1/rentals/:name` | Edit draft |
| POST | `/api/v1/rentals/:name/submit` | Active — atomic availability check |
| POST | `/api/v1/rentals/:name/return` | Return — release serials/qty |
| PATCH | `/api/v1/rentals/:name/lines/:idx/damage` | damage_notes |

### Dashboard

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/dashboard/stats` | active / overdue / available serialized + qty summary |

### Warehouse (existing — add v1 aliases)

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/warehouse/audit` | Was `/api/audit_container` |
| POST | `/api/v1/warehouse/session/start` | Dispatch/return session |
| POST | `/api/v1/warehouse/session/scan` | Add serial |
| POST | `/api/v1/warehouse/session/end` | Reconcile |
| POST | `/api/v1/warehouse/session/confirm` | Stock Entry |

---

## Concept mapping (Flutter prototype → ERPNext)

The Flutter app was built against Supabase table shapes. ERPNext uses different DocTypes — this table guides the rewrite, **not a data migration**.

| Flutter / Supabase concept | ERPNext |
|---|---|
| `categories` | Item Group |
| `equipment` (serialized) | Item + one or more Serial No |
| `equipment` (no serial, if any) | Item (`has_serial_no=0`) |
| `clients` | Customer (+ `id_document`) |
| `rentals` + `rental_items` | Equipment Rental + lines (`serialized` \| `qty`) |
| `profiles` + auth.users | ERPNext User |

**Status derivation (no more `equipment.status` column in app logic):**

| Former status | ERPNext rule |
|---|---|
| available | Serial not on Active rental; qty stock > 0 |
| rented | Serial/qty on Active Equipment Rental line |
| maintenance | Serial warehouse = `Maintenance - {abbr}` |
| retired | Item disabled or serial inactive |

---

## Greenfield go-live (D3 — no migration)

There is **no legacy inventory or rental data**. Do not build ETL, cutover scripts, or archive exports.

### Initial production data (before staff use)

Use existing pilot seed as template, then enter real company data in ERPNext desk or via MCP admin tools:

| Step | Action |
|---|---|
| 1 | Item Groups + Items (serialized + qty items) |
| 2 | Serial Nos (barcode = serial name) |
| 3 | Opening stock / Material Receipt into Main Store |
| 4 | Material Transfer into container warehouses (see `implementationerp.md` §0.0) |
| 5 | Customers (production client list) |
| 6 | ERPNext Users for staff (replace Supabase Auth accounts) |

**Already exists locally:** `bench execute lightbenders_warehouse.setup.seed_pilot.seed_all` — use for dev/staging; clone pattern for production seed, not one-click copy.

### Supabase prototype (Phase U4)

| Action | Detail |
|---|---|
| Stop using Supabase | Remove `supabase_flutter`, `--dart-define=SUPABASE_*`, repos pointing at Postgres |
| Prototype data | **Discard** — no export required |
| Supabase project | Delete or leave unused; no archive obligation |

### Go-live gate

Production go-live = ERPNext seeded with real inventory + staff Users created + Flutter on MCP + scanner-web on MCP. **First rental created in Flutter is rental #1 in company history.**

---

## Flutter changes (by phase — no coding now)

Keep layered architecture per `CLAUDE.md`. Swap repository implementations only; screens evolve for hybrid UI in U2/U3.

| Phase | Flutter work |
|---|---|
| U1 | `mcp_client.dart`, secure storage, ERPNext login, read-only lists |
| U2 | Hybrid item detail (serials + qty); forms → MCP write |
| U3 | Rental form: serial picker + qty lines; return flow |
| U4 | Remove Supabase; production go-live checklist |
| U5 | Warehouse screens → MCP warehouse v1 routes |

### New compile-time config

```bash
flutter run \
  --dart-define=MCP_BASE_URL=http://localhost:3001 \
  --dart-define=MCP_API_VERSION=v1
```

After U4: **remove** `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

---

## Skills registry (skills.sh — use during implementation)

Install project-local skills into `.agents/skills/` before each phase. Prefer **≥100 installs** and official/domain sources.

### By component

| Component | Skill | Installs | Install | Phase |
|---|---|---:|---|---|
| **Frappe app scaffold** | [frappe-app-development](https://skills.sh/lubusin/agent-skills/frappe-app-development) | 195 | `npx skills add lubusin/agent-skills@frappe-app-development -y` | U0 |
| **DocTypes + validation** | [frappe-doctype-development](https://skills.sh/lubusin/agent-skills/frappe-doctype-development) | 162 | `npx skills add lubusin/agent-skills@frappe-doctype-development -y` | U0 |
| **ERPNext API patterns** | [erpnext (Membrane)](https://skills.sh/membranedev/application-skills/erpnext) | 156 | `npx skills add membranedev/application-skills@erpnext -y` | U0–U3 |
| **Bench / migrate** | [bench-commands](https://skills.sh/unityappsuite/frappe-claude/bench-commands) | 30 | `npx skills add unityappsuite/frappe-claude@bench-commands -y` | U0, U6 |
| **MCP TypeScript server** | [typescript-mcp-server-generator](https://skills.sh/github/awesome-copilot/typescript-mcp-server-generator) | 10.8K | already in `~/.agents/skills/` | U1 |
| **Express API layer** | [express](https://skills.sh/blencorp/claude-code-kit/express) | 48 | optional — use if extending MCP HTTP | U1 |
| **Flutter architecture** | [flutter-apply-architecture-best-practices](https://skills.sh/flutter/skills/flutter-apply-architecture-best-practices) | official | already in `.agents/skills/` | U1–U5 |
| **Flutter HTTP client** | [flutter-networking](https://skills.sh/madteacher/mad-agents-skills/flutter-networking) | 626 | `npx skills add madteacher/mad-agents-skills@flutter-networking -y` | U1 |
| **Flutter integration tests** | [flutter-add-integration-test](https://skills.sh/flutter/skills/flutter-add-integration-test) | 18.4K | `npx skills add flutter/skills@flutter-add-integration-test -y` | U3 |
| **Production seed / go-live** | [bench-commands](https://skills.sh/unityappsuite/frappe-claude/bench-commands) | 30 | already listed above | U4, U6 |
| **Warehouse UI (U5)** | [frontend-design](https://skills.sh/) | — | already in `.agents/skills/` | U5 |

### Skills explicitly NOT used

| Skill | Reason |
|---|---|
| Generic `auth-security-expert` (<100 installs) | JWT/session spec defined in this doc |
| Flutter feature-first architecture | Conflicts with existing `core/models/repos/providers/screens` layout in `CLAUDE.md` |
| Direct ERPNext calls from Flutter | Violates MCP boundary |

### Agent rule

Before implementing any phase, **read the assigned skill SKILL.md** for that component. Do not improvise ERPNext or Frappe patterns when a skill exists.

---

## Phased delivery & gates

### Phase U0 — ERPNext schema & rules

**Skills:** frappe-app-development, frappe-doctype-development, erpnext, bench-commands

**Deliverables**

- [ ] `Equipment Rental` + `Equipment Rental Item` DocTypes
- [ ] Customer `id_document` field
- [ ] Submit/return validations (serial overlap + qty stock)
- [ ] Role matrix signed off
- [ ] Manual desk test: create Active rental with 1 serial line + 1 qty line

**Gate:** Cannot double-book serial; qty line blocked when stock insufficient.

---

### Phase U1 — MCP auth + read API + Flutter read-only

**Skills:** typescript-mcp-server-generator, erpnext, flutter-networking, flutter-apply-architecture-best-practices

**Deliverables**

- [ ] `docs/api-v1.md` or OpenAPI spec
- [ ] MCP session store + JWT auth routes
- [ ] Read routes: items, serials, customers, rentals, dashboard
- [ ] Flutter: login + read-only screens on MCP
- [ ] Unit tests: MCP auth middleware; ERPNext session mock

**Gate:** Flutter lists match ERPNext desk; no secrets in APK; 401 on expired session.

---

### Phase U2 — Writes + hybrid UI

**Skills:** frappe-doctype-development, flutter-apply-architecture-best-practices

**Deliverables**

- [ ] MCP write routes: items, customers, serials
- [ ] Flutter: Item list → detail with serial sub-list + qty on hand
- [ ] Equipment form → MCP

**Gate:** Create customer in Flutter → visible in ERPNext.

---

### Phase U3 — Rentals end-to-end

**Skills:** frappe-doctype-development, erpnext, flutter-add-integration-test

**Deliverables**

- [ ] MCP rental CRUD + submit + return
- [ ] Flutter rental form: serial picker + qty stepper lines
- [ ] Integration test: create → submit → return → serial available again

**Gate:** Double-book rejected with `SERIAL_ALREADY_RENTED`; qty over-stock rejected with `INSUFFICIENT_QTY`.

---

### Phase U4 — Supabase removal & production go-live

**Skills:** bench-commands, erpnext

**Deliverables**

- [ ] Remove `supabase_flutter` and all Supabase repos from Flutter
- [ ] App runs with `--dart-define=MCP_BASE_URL` only
- [ ] Production seed: real Items, Serials, Customers, Users in ERPNext (not pilot dev data)
- [ ] Go-live checklist: staff Users, opening stock, container transfers complete

**Gate:** First production rental created in Flutter; no Supabase dependency in build; ERPNext is sole ledger from Day 1.

---

### Phase U5 — Flutter warehouse tab

**Skills:** frontend-design, typescript-mcp-server-generator (warehouse v1 aliases)

**Deliverables**

- [ ] Flutter warehouse screens calling `/api/v1/warehouse/*`
- [ ] scanner-web unchanged (parallel)

**Gate:** Audit TRAY-004 matches scanner-web.

---

### Phase U6 — Production VPS

**Skills:** erpnext, bench-commands

**Deliverables**

- [ ] HTTPS MCP + ERPNext
- [ ] Redis session store
- [ ] `MCP_JWT_SECRET` + rotated ERPNext keys
- [ ] Flutter production `MCP_BASE_URL`

**Gate:** iPad scanner-web + Flutter office on same MCP production instance.

---

## Reliability checklist (every phase)

- [ ] Assigned skill read before coding
- [ ] API changes documented in `docs/api-v1.md`
- [ ] Stable error codes — no raw ERPNext trace in Flutter UI
- [ ] ERPNext session expiry handled (`SESSION_EXPIRED`)
- [ ] No ERPNext service keys in Flutter or scanner-web builds
- [ ] Idempotency on rental submit where applicable
- [ ] Phase gate tests pass before next phase

---

## scanner-web relationship

| Period | scanner-web | Flutter |
|---|---|---|
| U1–U4 | Primary warehouse (iPad + gun) | Office inventory/rentals |
| U5+ | Kept for crew preferring Safari | Optional warehouse tab |

Both use **same MCP** — warehouse routes gain `/api/v1/warehouse/*` aliases; old paths deprecated.

---

## Success criteria (definition of done)

- [ ] Flutter runs with **MCP only** (no Supabase)
- [ ] Inventory, clients, rentals live in ERPNext from Day 1 (greenfield)
- [ ] Hybrid UI: Items → Serials; rentals support serial + qty lines
- [ ] JWT auth; ERPNext sid server-side only
- [ ] No legacy migration — first company rental is created in ERPNext via Flutter
- [ ] No double-booking serials across Flutter, desk, scanner-web
- [ ] Each phase completed with assigned skills + gate tests

---

## Local dev stack

```bash
# ERPNext bench     → http://localhost:8080
cd mcp-server && npm run dev      # → http://localhost:3001
cd scanner-web && npm run dev     # → http://localhost:5173

flutter run \
  --dart-define=MCP_BASE_URL=http://localhost:3001 \
  --dart-define=MCP_API_VERSION=v1
```

---

## Document history

| Date | Change |
|---|---|
| 2026-06-27 | Initial plan |
| 2026-06-27 | Locked D1–D5; skills registry; API v1 spec; reliability gates |
| 2026-06-27 | Greenfield: no cutover, no migration, no rental history archive |
