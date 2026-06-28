# Lightbenders Smart Inventory System — Implementation Plan

> **Business context:** Professional film equipment rental warehouse — lights, lenses, grip (carts, C-stands, sandbags), camera support, large rigs. Not a single product type; trays and carts hold **mixed, configurable** contents. Each **physical asset** has its own barcode; multi-part equipment is modeled as an **assembly** of serialized (or qty-tracked) components.

---

## The Idea in 60 Seconds

Lightbenders rents professional film production gear. Real warehouse reality:

- A **light** might be 3 barcoded parts (lamp head, lens, diffuser).
- A **dolly system** might be 5+ barcoded parts (base, track sections, clamps).
- A **grip cart** might hold C-stand legs, arms, heads, sandbags, apple boxes — all different item types.
- Each **tray, cart, or rack** has its **own barcode** and holds a **mix** of equipment — not always the same layout.

**Every physical piece that gets scanned** = one barcode = one **Serial No** in ERPNext (or qty item for non-serialized consumables later).

**Warehouse crew (non-technical):**

1. iPad + **Bluetooth barcode gun** (already purchased — HID keyboard mode).
2. Simple **web chat** — scan and read plain English results.
3. **Three scan modes:**
   - **Quick audit** — scan container only → quantity check vs config + Stock Balance
   - **Dispatch** — scan source cart → scan truck → scan every serial → load truck
   - **Return** — scan truck → scan destination cart → scan every serial → put away

**ERPNext on VPS** = inventory truth. **MCP server** = bridge (crew never use ERPNext desk). **Flutter + Supabase** = office rentals for now; **long-term migrate to ERPNext** if it covers all business needs.

---

## Locked Decisions (from stakeholder answers — 2026-06-27)

| Topic | Decision |
|---|---|
| Container contents | **Mixed** — lights, grip, camera support, large gear on different trays/carts |
| Expected contents | **Configurable per container** — editable in ERPNext without code changes; not hardcoded kit counts |
| Quick warehouse audit | **Scan container barcode only** → quantity check vs config |
| Dispatch | **Scan every item** — source container → destination truck; Stock Entry on confirm |
| Return | **Scan every item** — source truck → destination container; Stock Entry on confirm |
| Scanner hardware | **Bluetooth HID gun — purchased** |
| Long-term backend | **Migrate to ERPNext** if it meets all business needs; Supabase/Flutter is interim for rentals |
| VPS hosting | ERPNext on VPS, HTTPS public URL (not localhost) |

### Deferred until deploy

| Topic | Status |
|---|---|
| VPS domain / URLs | **TBD until deploy** — use placeholder `erp.<domain>` / `scan.<domain>` in docs; set in env at deploy time |

### Locked (2026-06-27)

| Topic | Decision |
|---|---|
| Dispatch paperwork | **iPad workflow is enough for V1** — no printed Pick List required; confirm on screen + Stock Entry in ERPNext is sufficient |

---

## Core Concepts (how the model scales beyond light kits)

### 1. Component — one barcoded physical asset

Each scannable sticker = **Serial No** in ERPNext, linked to an **Item** (item code).

```
LB-LAMP-0042  →  Item: ARRI-LAMP-HEAD
LB-CS-ARM-017 →  Item: C-STAND-ARM
LB-DOLLY-BASE →  Item: FISHER-DOLLY-BASE
```

Some large gear may be **one serial = whole unit** (single barcode on the case). Multi-part gear uses **multiple serials = one logical assembly**.

### 2. Equipment Assembly — "one whole equipment, many parts"

A **template** for equipment that only works when its parts are together.

Custom DocType **`Equipment Assembly`** (Frappe app or ERPNext customize):

| Field | Example |
|---|---|
| `assembly_name` | ARRI Light Set, Fisher Dolly System, Matthews C-Stand (complete) |
| Child table `components` | `item_code` + `qty` per row |

```
Equipment Assembly: ARRI-LIGHT-SET
  1 × ARRI-LAMP-HEAD
  1 × ARRI-LENS
  1 × ARRI-DIFFUSER

Equipment Assembly: FISHER-DOLLY-SYSTEM
  1 × FISHER-DOLLY-BASE
  4 × FISHER-TRACK-SECTION
  4 × FISHER-TRACK-CLAMP
```

**Product Bundle** (ERPNext native) can mirror the same recipe for **sales/rental quotes**. Use Assembly as the warehouse/audit source of truth; keep Product Bundle in sync for when rentals move into ERPNext (long-term).

Parts of the same item type are **interchangeable** (any valid lens with any lamp) unless you later add optional **set assignment** (V2).

### 3. Container — tray, cart, stand rack (configurable contents)

Custom DocType **`Warehouse Container`** (name TBD — "Rack Tray", "Cart", etc.):

| Field | Purpose |
|---|---|
| `container_barcode` | Sticker on physical unit — `TRAY-004`, `CART-012` |
| `warehouse` | Link to child **Warehouse** in ERPNext (stock location) |
| `container_type` | tray \| cart \| rack \| truck_bay |
| `label` | Human name — "Grip Cart B", "Light Tray 04" |
| Child table `expected_contents` | **Configurable lines** — see below |

**`expected_contents` child table** (this is the key to mixed + configurable):

| Column | Meaning |
|---|---|
| `item_code` | Expected item type (direct line; use when not using assembly row) |
| `qty` | How many should be here |
| `equipment_assembly` | Link to Assembly — **MCP expands at audit/session time** (not on desk save) |
| `tracking` | `serialized` (default — in audit diff) \| `qty_only` (V1: UI label only, excluded from diff) |

Example — **mixed grip cart** (editable anytime in ERPNext desk):

```
Container: CART-012 "Grip Cart B"
  4 × C-STAND-LEG          [serialized — V1 audited]
  4 × C-STAND-ARM          [serialized — V1 audited]
  4 × C-STAND-HEAD         [serialized — V1 audited]
  2 × ARRI-LIGHT-SET       [assembly row — MCP expands at audit time]
  8 × SANDBAG-25LB         [qty_only — V1: shown in UI as "not tracked yet", excluded from diff]
```

**V1 config rule:** Pilot containers use **serialized lines and assembly rows only**. Qty-only lines (sandbags, expendables) may appear in config but are tagged `tracking: qty_only` — UI shows them greyed with *"Not tracked in V1"* and MCP **excludes them from missing/surplus diff** until V1.1.

Example — **light tray** (different container, different config):

```
Container: TRAY-004 "Light Tray 04"
  4 × ARRI-LAMP-HEAD
  4 × ARRI-LENS
  4 × ARRI-DIFFUSER
  (same as 4× ARRI-LIGHT-SET expanded — staff can edit either way)
```

When prep changes a cart layout for a job, **update the container config in ERPNext** — no deploy, no developer.

### 4. Container = Warehouse in ERPNext

Every physical container maps to a **child warehouse**. Serial numbers live in that warehouse **only after a Stock Entry records them there**.

> **Ledger rule (non-negotiable):** If a serial is physically on a cart but ERPNext still shows `Main Store - LB`, audit mode will report it **missing from the cart**. Every physical move must have a matching Stock Entry. The scan app cannot fix stale ledger data — it exposes it.

```
Main Store - LB
├── Containers - LB
│   ├── Rack Tray 04 - LB      ← TRAY-004
│   ├── Grip Cart 12 - LB      ← CART-012
│   └── Camera Cart 03 - LB    ← CART-003
├── Truck 1 - LB
├── Truck 2 - LB
└── Maintenance - LB
```

---

## Concrete Examples

### Example A — Light tray (original Vishist case)

```
Scan TRAY-004 (audit mode):
  Expected (from container config):  4 lamp, 4 lens, 4 diffuser
  Actual (Stock Balance in warehouse): 4 lamp, 4 lens, 3 diffuser
  → "Missing 1× ARRI-DIFFUSER"
```

### Example B — Mixed grip cart

```
Scan CART-012 (audit mode):
  Expected:  4 C-stand heads, 4 arms, 4 legs
  Actual:    4, 3, 4
  → "Missing 1× C-STAND-ARM"
```

### Example C — Dispatch to truck (scan every item)

```
1. Mode: Dispatch → scan source CART-012 → scan destination TRUCK-1 (or select Truck 1)
2. Scan LB-CS-HEAD-001    → ✓
3. Scan LB-CS-ARM-007     → ✓
   ... (continuous scan — gun sends Enter after each)
4. End session:
   Expected 4 arms, scanned 3 → "Under-packed: missing 1× C-STAND-ARM"
5. Tap Confirm anyway? → optional reason → Stock Entry: Grip Cart 12 → Truck 1
```

### Example D — Return from shoot (scan every item)

```
1. Mode: Return → scan source TRUCK-1 → scan destination CART-012
2. Scan each serial coming off the truck into the cart
3. End session → reconcile vs expected_contents for CART-012
4. Confirm → Stock Entry: Truck 1 → Grip Cart 12
```

---

## Resolved Technical Decisions (V1)

| # | Decision | V1 choice |
|---|---|---|
| 1 | ERPNext hosting | **VPS**, HTTPS public URL |
| 2 | V1 app split | **Option C** — Flutter/Supabase office; ERPNext scanner for warehouse |
| 3 | Warehouse UI | **Web chat + Bluetooth HID gun** on iPad |
| 4 | Middleware | **MCP server on VPS** — API keys server-side only |
| 5 | Container contents | **Configurable `Warehouse Container` DocType** — mixed item lines |
| 6 | Multi-part equipment | **`Equipment Assembly` templates** + optional Product Bundle for sales |
| 7 | Piece identity | **Barcode = Serial No** for serialized assets |
| 8 | Scan modes | **Audit** + **Dispatch** + **Return** (dispatch/return = every serial) |
| 9 | Assembly expansion | **MCP runtime** — `expand_assembly()` called inside `audit_container` and `end_session` before diff |
| 10 | Under-packed dispatch | **V1 soft block** — confirm dialog "Proceed anyway?" + optional reason; PIN override V1.1 |
| 11 | Long-term | **ERPNext becomes primary** if validation passes — see [Migration path](#long-term-migration-supabase--erpnext) |

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  iPad — Safari + Bluetooth HID barcode gun (owned)             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  scanner-web/                                          │  │
│  │  Mode: [Audit] [Dispatch] [Return]                     │  │
│  │  Scan → chat bubbles, large text, green/yellow/red     │  │
│  └──────────────────────────┬─────────────────────────────┘  │
└─────────────────────────────┼────────────────────────────────┘
                              │ HTTPS
                              ▼
┌──────────────────────────────────────────────────────────────┐
│  VPS                                                         │
│  ┌─────────────────────┐      ┌──────────────────────────┐  │
│  │  MCP Server         │ REST │  ERPNext v16.25          │  │
│  │  • audit_container  │─────→│  • Items + Serial Nos    │  │
│  │  • scan_serial      │      │  • Equipment Assembly    │  │
│  │  • end_session      │      │  • Warehouse Container   │  │
│  │  • transfer_container      │  • Warehouses            │  │
│  │  • flag_damaged     │      │  • Stock Entry           │  │
│  └─────────────────────┘      └──────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Flutter + Supabase (interim) — office rentals/clients       │
│  Long-term: migrate bookings here → ERPNext                  │
└──────────────────────────────────────────────────────────────┘
```

---

## Infrastructure (VPS)

| Item | Requirement |
|---|---|
| ERPNext | `https://erp.<domain>` — TLS required |
| Scanner app | `https://scan.<domain>` |
| MCP server | Same VPS, `/api` routes or subdomain — **holds API keys** |
| iPad | Internet (WiFi/cellular) — gun paired as Bluetooth keyboard |
| Never | `localhost` on iPad |

```
[ ] 0.N1  iPad opens ERPNext URL
[ ] 0.N2  iPad opens scanner URL
[ ] 0.N3  MCP health check from iPad
[ ] 0.N4  MCP → ERPNext API key works
[ ] 0.N5  Bluetooth gun scan appears in scanner input field
```

---

## ERPNext Data Model (Phase 0)

### 0.0 — Initial stock load (required before audit works)

Audit mode compares **container config** vs **Stock Balance in the container warehouse**. That only works if serials were moved into that warehouse when physically placed on the cart/tray.

**One-time bootstrap (desk or API):**

1. Create all **Serial No** records (barcode = serial name).
2. **Opening stock** or **Material Receipt** into `Main Store - LB` for new inventory.
3. **Material Transfer** per container: move each serial from Main Store → container warehouse (e.g. `Grip Cart 12 - LB`).
4. Verify: Stock Balance for `Grip Cart 12 - LB` matches physical count before any app testing.

**Ongoing discipline (document for warehouse managers):**

| Physical event | ERPNext action |
|---|---|
| Piece placed on cart | Material Transfer → container warehouse (or scan-app dispatch/return session on confirm) |
| Cart loaded on truck | Dispatch session → Stock Entry to `Truck N - LB` |
| Gear returns from shoot | Return session → Stock Entry to container warehouse |
| Piece removed for repair | Stock Entry → `Maintenance - LB` |

```
[ ] 0.0a  Serial nos exist for all pilot stickers
[ ] 0.0b  Opening stock / receipt into Main Store
[ ] 0.0c  Material Transfer: pilot serials → TRAY-004 and CART-012 warehouses
[ ] 0.0d  Stock Balance API matches physical walk-through of both containers
```

**0.0 must pass before 0.5a–0.5e.**

### 0.1 — Item groups & serialized items

```
Lighting      → ARRI-LAMP-HEAD, ARRI-LENS, ARRI-DIFFUSER, …
Grip/Support  → C-STAND-LEG, C-STAND-ARM, C-STAND-HEAD, …
Camera Support→ (heads, plates, rods — each serialized as needed)
Power         → …
```

Rule: if it gets its **own barcode sticker**, it gets `has_serial_no = 1` and a Serial No record.

**Qty-only items (sandbags, expendables):** deferred to **V1.1**. In V1, if listed in `expected_contents`, mark `tracking: qty_only` — UI shows *"Not tracked in V1"* and MCP skips them in diff (see §0.3).

### 0.2 — Equipment Assembly (multi-part equipment templates)

Custom DocType with component child table. Seed at least:

- `ARRI-LIGHT-SET` (3 components)
- One grip example, e.g. `C-STAND-COMPLETE` (leg + arm + head)
- One large/multi-part example from Lightbenders pilot list (dolly or camera support)

Optional: duplicate composition as **Product Bundle** for future rental quoting in ERPNext.

### 0.3 — Warehouse Container (configurable expected contents)

Custom DocType — **the main config surface for warehouse managers.**

```
container_barcode  →  warehouse link  →  expected_contents[]
```

Managers edit `expected_contents` when cart layout changes.

**`expected_contents` columns:**

| Column | Purpose |
|---|---|
| `item_code` | Serialized item (direct line) |
| `qty` | Expected count |
| `equipment_assembly` | Optional — link to Assembly instead of single item |
| `tracking` | `serialized` (default, V1 audited) \| `qty_only` (V1: UI only, excluded from diff) |

**Assembly expansion (explicit design):** MCP expands at **query time**, not on save in ERPNext desk.

1. Load raw `expected_contents` from `Warehouse Container`.
2. Call `expand_assembly()` — assembly rows multiply into component item lines; merge with direct item lines; sum quantities per `item_code`.
3. Filter out `tracking: qty_only` lines from diff (keep in UI as informational).
4. Diff expanded expected list vs Stock Balance (audit) or vs scanned serials (dispatch/return).

`expand_assembly.ts` is **not optional** — `audit_container` and `end_session` must call it internally on every request.

### 0.4 — Warehouse hierarchy

Create child warehouse per container. Barcode → lookup `Warehouse Container` → warehouse name.

### 0.5 — Phase 0 validation gate

Pilot with **two container types** (prove mixed + configurable):

```
[ ] 0.5a  After 0.0: light tray TRAY-004 has serials in warehouse via Stock Entry; remove 1 diffuser via transfer out
[ ] 0.5b  Audit API → "Missing 1× ARRI-DIFFUSER"
[ ] 0.5c  Grip cart CART-012: mixed config, 1 arm missing → audit catches it
[ ] 0.5d  Dispatch session: scan every serial on TRAY-004 → reconcile matches audit
[ ] 0.5e  Return session: truck → TRAY-004 → serials land in tray warehouse; audit passes
[ ] 0.5f  Change TRAY-004 config (4→3 kits) in desk → audit reflects new expected without code deploy
[ ] 0.5g  Config with qty_only line (sandbag) → UI shows "not tracked"; audit does not false-flag missing sandbags
```

---

## Warehouse Workflows

### Mode 1 — Quick audit (scan container only)

**When:** walk the warehouse, spot-check a cart or tray.

**Depends on:** Stock Balance in container warehouse is up to date (see §0.0).

1. Select **Audit** mode.
2. Scan `CART-012` / `TRAY-004`.
3. MCP `audit_container`:
   - Load `Warehouse Container.expected_contents`
   - **`expand_assembly()`** → flat expected list (serialized lines only for diff)
   - Fetch Stock Balance for linked warehouse (group by item)
   - Diff expected vs actual
   - Attach `qty_only` lines separately for UI display (not in diff)
4. Display: *"Grip Cart B: missing 1× C-STAND-ARM"* + grey *"8× sandbag — not tracked in V1"* if configured.

No individual serial scans required.

### Mode 2 — Dispatch to truck (scan every item)

**When:** loading truck for a shoot — **full accountability before leave**.

| Step | Action |
|---|---|
| 1 | Select **Dispatch** mode |
| 2 | Scan **source container** barcode (`CART-012`) |
| 3 | Scan or select **destination** (`TRUCK-1` / Truck 1 - LB) |
| 4 | Continuous scan **every serial** on the cart (Enter after each beep) |
| 5 | `end_session`: **`expand_assembly()`** → compare scanned serials (by item type) vs expanded expected |
| 6 | If complete → **Confirm** → Stock Entry: container warehouse → truck warehouse (for **scanned serials**) |
| 7 | If under-packed or unexpected → **soft block** (see below) |

**Stock Entry scope:** moves **scanned serials** from source container warehouse to truck — not blind "move everything ERPNext thinks is in the warehouse."

### Mode 3 — Return from shoot (scan every item)

**When:** gear comes back — mirror of dispatch, reversed direction.

| Step | Action |
|---|---|
| 1 | Select **Return** mode |
| 2 | Scan **source** truck barcode (`TRUCK-1`) |
| 3 | Scan **destination container** barcode (`CART-012`) |
| 4 | Continuous scan every serial being unloaded into the cart |
| 5 | `end_session`: reconcile vs **destination** container's expanded expected_contents |
| 6 | Soft block if under-packed vs expected (same confirm flow as dispatch) |
| 7 | **Confirm** → Stock Entry: truck warehouse → destination container warehouse (scanned serials) |

**Return differs from dispatch:** source is truck, destination is container, expected list comes from **destination** container config.

### Under-packed confirm (V1 — required)

If `end_session` reports missing items or unexpected serials:

1. **Do not hard-block silently** — show clear list of gaps.
2. Primary button: **Go back and scan** (default).
3. Secondary button: **Proceed anyway** → confirmation dialog: *"Missing 1× C-STAND-ARM. Load anyway?"*
4. Optional short reason text (stored on session log / Stock Entry remark).
5. **V1.1:** supervisor PIN required for proceed on dispatch (configurable).

Hard block with no escape is **not acceptable** for live warehouse launch.

### Mode 4 — Damaged return (V1.1)

Scan serial + flag → move to `Maintenance - LB`, add damage note.

---

## Build Phases

### Phase 0 — ERPNext custom DocTypes + pilot data on VPS

1. **0.0** Initial stock load — serials into container warehouses via Stock Entry
2. Frappe custom app or Customize: `Equipment Assembly`, `Warehouse Container`
3. Item groups + pilot serials (light tray + grip cart)
4. Two container records with different `expected_contents` (serialized + assembly rows only; optional qty_only demo line for 0.5g)
5. Validation gate 0.5a–0.5g (after 0.0)

### Phase 1 — MCP server (`mcp-server/`)

```
mcp-server/src/
  lib/
    expand_assembly.ts      # REQUIRED — called by audit_container + end_session
    resolve_expected.ts     # load config → expand → filter qty_only for diff
  tools/
    audit_container.ts      # Mode 1
    start_session.ts        # Mode 2/3 — { mode, source, destination }
    scan_serial.ts          # add serial to open session
    end_session.ts          # reconcile; returns complete + gaps
    confirm_session.ts      # Stock Entry; accepts proceed_anyway + reason
```

**`expand_assembly` (internal — always runs before diff)**

```
Input:  expected_contents[] (raw from Warehouse Container)
Output: { audited: [{item, qty}], informational: [{item, qty, tracking: qty_only}] }
```

**`audit_container`**

```
Input:  container_barcode
Flow:   resolve_expected() → Stock Balance → diff audited lines only
Output: { label, expected, actual, missing, surplus, not_tracked_v1: [...] }
```

**`start_session`**

```
Input:  mode: "dispatch"|"return", source_barcode, destination_barcode
Output: { session_id, expected_audited, source_warehouse, dest_warehouse }
```

**`end_session`**

```
Input:  session_id
Flow:   resolve_expected() for destination container → compare scanned serials by item
Output: { scanned: [{serial, item}], missing, unexpected, complete: bool }
```

**`confirm_session`**

```
Input:  session_id, proceed_anyway?: bool, reason?: string
Flow:   if !complete && !proceed_anyway → reject; else Material Transfer scanned serials source → dest
Output: { stock_entry_id, items_moved }
```

### Phase 2 — Scanner web app (`scanner-web/`)

- Mode toggle: **Audit** | **Dispatch** | **Return**
- HID continuous scan (purchased gun)
- Chat-style results; no ERPNext jargon
- **`not_tracked_v1` lines** shown greyed — never silent omission
- **Under-packed flow (V1):** gap list → "Go back and scan" | "Proceed anyway" → reason → confirm
- Calls MCP only — no ERPNext keys in browser

```
[ ] 2.4  Proceed-anyway confirmation dialog + reason field
[ ] 2.5  Return mode: source truck → dest container scan order enforced in UI
```

### Phase 3 — VPS deploy + iPad pilot

Real containers, real barcodes, warehouse crew smoke test.

### Phase 4 — Flutter / Supabase

**No V1 changes.** Office staff keep current app until ERPNext rental module validated.

---

## Long-term migration (Supabase → ERPNext)

Goal: **ERPNext becomes the single system** if it meets all business needs.

| Phase | Scope |
|---|---|
| **V1** | Warehouse inventory + scan app on ERPNext; rentals stay in Supabase/Flutter |
| **V1 eval** | Run parallel; confirm ERPNext handles serial tracking, containers, dispatch, damage, reporting |
| **V2** | Rental bookings → ERPNext (Sales Order / Project / custom Rental DocType) |
| **V2** | Flutter app reads ERPNext API for equipment availability OR replace with ERPNext desk + scanner only |
| **V3** | Decommission Supabase equipment tables; auth strategy TBD (ERPNext users vs Supabase auth) |

Success criteria before migration:

- [ ] All serialized assets in ERPNext
- [ ] Container audit + dispatch workflows trusted by crew
- [ ] Rental availability reflects physical stock (no double-booking)
- [ ] Financial/reporting needs met (invoicing, projects, cross-rental PO — later)

---

## MCP + Chat: V1 vs later

| Capability | V1 | V1.1+ |
|---|---|---|
| Audit mode (container only) | Yes | — |
| Dispatch/return (every serial) | Yes | — |
| Configurable container contents | Yes (ERPNext desk) | — |
| Mixed carts + assemblies | Yes | — |
| Move container to truck | Yes | — |
| LLM / voice commands | Rule-based | Claude/Gemini |
| Qty-only items in audit diff | Excluded — UI shows "not tracked in V1" | Full qty audit |
| Under-packed proceed anyway | Yes — confirm + reason | Optional supervisor PIN |
| Pick List / printed dispatch sheet | No (V1) | Optional V2 if ops asks |
| Damaged item workflow | — | V1.1 |
| Offline scan queue | — | V2 |

---

## Build Order

```
Phase 0 — ERPNext on VPS
  [ ] 0.0  Initial stock load — serials into container warehouses (0.0a–0.0d)
  [ ] 0.1  Item groups + serialized pilot items (light + grip + 1 large assembly)
  [ ] 0.2  Equipment Assembly DocType + 3 seed assemblies
  [ ] 0.3  Warehouse Container DocType + expected_contents (tracking column)
  [ ] 0.4  Warehouse hierarchy + 2 pilot containers (TRAY-004, CART-012)
  [ ] 0.5  Validation 0.5a–0.5g
  [ ] 0.N  Network + iPad + barcode gun checklist

Phase 1 — MCP server
  [ ] 1.1  erpnext_client.ts
  [ ] 1.2  expand_assembly + resolve_expected (used by audit + session)
  [ ] 1.3  audit_container
  [ ] 1.4  start_session + scan_serial + end_session + confirm_session

Phase 2 — scanner-web
  [ ] 2.1  Audit / Dispatch / Return mode toggle
  [ ] 2.2  HID continuous scan
  [ ] 2.3  Chat UI + mcp_client + not_tracked_v1 display
  [ ] 2.4  Proceed-anyway confirmation + reason
  [ ] 2.5  Return scan order (truck → container)

Phase 3 — VPS deploy + crew pilot

--- Later ---
  V1.1  Voice, damage, non-serial qty items
  V2    ERPNext rentals, Supabase migration, offline queue
```

---

## Verification Plan

### Phase 0

- **0.0:** Stock Balance matches physical placement after Material Transfer into container warehouses.
- Two container configs audit correctly (light tray + mixed grip cart).
- **0.5g:** qty_only line visible in UI, excluded from missing/surplus diff.
- Editing container config in ERPNext desk changes audit output without redeploy.

### Phase 1–3 (iPad + purchased gun)

1. **Audit:** scan `CART-012` only → missing part message; sandbags show "not tracked in V1" if configured.
2. **Dispatch:** source cart → dest truck → scan every serial → complete session → Stock Entry.
3. **Return:** source truck → dest cart → scan every serial → Stock Entry back to cart warehouse.
4. **Under-packed:** skip one serial → gap list → "Proceed anyway" with reason → Stock Entry still works.
5. Gun continuous scan: no tap between items; Enter clears input for next.
6. Browser network tab shows MCP calls only — no ERPNext API keys.

### Flutter

- Unchanged; regression clean.

---

## Review Log

| Date | Change |
|---|---|
| 2026-06-27 | Vishist brief: VPS, MCP chat, ARRI tray example |
| 2026-06-27 | Stakeholder answers: mixed configurable containers, dual scan modes, HID gun owned, ERPNext long-term primary |
| 2026-06-27 | Scaled model: Equipment Assembly, Warehouse Container, grip/large gear — not light-kits-only |
| 2026-06-27 | Dispatch: iPad-only confirm (no Pick List V1); VPS URLs TBD until deploy |
| 2026-06-27 | Pressure-test fixes: §0.0 stock load, Dispatch/Return split, runtime assembly expansion, qty_only UI, proceed-anyway V1 |
