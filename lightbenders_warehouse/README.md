# Phase 0 — ERPNext custom app (Lightbenders Warehouse)

Frappe app for **Phase 0** of [implementationerp.md](../implementationerp.md): custom DocTypes, pilot data, and stock bootstrap on ERPNext v16.

## Skills used (skills.sh)

| Layer | Skill | Purpose |
|---|---|---|
| Frappe app scaffold | [frappe-app-development](https://skills.sh/lubusin/agent-skills/frappe-app-development) | App structure, hooks, patches, service layer |
| ERPNext API (VPS) | [erpnext (Membrane)](https://skills.sh/membranedev/application-skills/erpnext) | Authenticated API — no guessed credentials |
| Flutter (unchanged V1) | [flutter-apply-architecture-best-practices](https://skills.sh/flutter/skills/flutter-apply-architecture-best-practices) | Office app stays as-is until Phase 4 |
| Supabase (unchanged V1) | [supabase](https://skills.sh/supabase/agent-skills/supabase) | Interim rentals backend |

Install Membrane CLI (ERPNext skill):

```bash
npm install -g @membranehq/cli@latest
npx @membranehq/cli login --tenant --clientName=cursor
npx @membranehq/cli connection ensure "https://erp.<your-domain>" --json
```

## DocTypes (§0.2–0.3)

| DocType | Purpose |
|---|---|
| **Equipment Assembly** | Multi-part equipment templates (lamp + lens + diffuser) |
| **Equipment Assembly Component** | Child table: item + qty |
| **Warehouse Container** | Physical tray/cart — barcode → warehouse link |
| **Warehouse Container Expected Content** | Configurable expected lines + `tracking` (`serialized` \| `qty_only`) |

Assembly expansion for audit diff lives in `services/expand_assembly.py` (same logic Phase 1 MCP will call).

## Install on VPS bench

```bash
# On ERPNext bench host
cd ~/frappe-bench
bench get-app /path/to/lightbenders_warehouse   # or git clone into apps/
bench --site erp.<domain> install-app lightbenders_warehouse
bench --site erp.<domain> migrate
```

Ensure `developer_mode` is on while iterating DocTypes:

```bash
bench --site erp.<domain> set-config developer_mode 1
bench restart
```

## Seed pilot data (§0.0–0.4)

**Explicit command** — not auto-run on install (avoids accidental stock on production):

```bash
bench --site erp.<domain> execute lightbenders_warehouse.setup.seed_pilot.seed_all
```

This creates:

- Item groups: Lighting, Grip/Support, Camera Support, Power
- Serialized pilot items (ARRI lamp/lens/diffuser, C-stand parts)
- Warehouse tree: Main Store → Containers → TRAY-004 / CART-012, Truck 1/2, Maintenance
- Equipment assemblies: `ARRI-LIGHT-SET`, `C-STAND-COMPLETE`
- Containers: `TRAY-004` (light tray), `CART-012` (mixed grip cart + qty_only sandbags)
- Serial Nos + Material Receipt → Main Store → Material Transfer into container warehouses

## Phase 0 validation (§0.5)

After seed, on bench:

```bash
bench --site erp.<domain> execute lightbenders_warehouse.setup.validate_pilot.validate_pilot
```

Manual gate checklist (requires Phase 1 MCP for full 0.5a–0.5g):

```
[ ] 0.0d  Stock Balance matches physical walk-through
[ ] 0.5a  Remove 1 diffuser via transfer → audit shows missing
[ ] 0.5b  Audit API → "Missing 1× ARRI-DIFFUSER"
[ ] 0.5c  CART-012 mixed config catches missing arm
[ ] 0.5d–0.5g  Dispatch/return + config edit + qty_only UI (Phase 1–2)
```

## Membrane — verify ERPNext connection (§0.N4)

```bash
npx @membranehq/cli action list --connectionId=CONNECTION_ID --intent "list items" --json
npx @membranehq/cli action run get-document --connectionId=CONNECTION_ID \
  --input '{"doctype":"Warehouse Container","name":"TRAY-004"}' --json
```

Use `create-document` / `get-document` for DocTypes — never hard-code API keys in this repo.

## File map

```
lightbenders_warehouse/
├── lightbenders_warehouse/
│   ├── hooks.py
│   ├── patches/v16_0/seed_pilot_data.py
│   ├── setup/seed_pilot.py          # §0.0 bootstrap
│   ├── setup/validate_pilot.py      # §0.5 helpers
│   ├── services/expand_assembly.py  # shared with Phase 1 MCP
│   └── lightbenders_warehouse/doctype/
│       ├── equipment_assembly/
│       └── warehouse_container/
└── README.md
```

## Next: Phase 1

MCP server in `mcp-server/` will call ERPNext via Membrane and use `expand_assembly` before every audit/session diff.
