# U4 Production Seed Checklist

ERPNext is the sole ledger from Day 1. Complete this checklist in ERPNext desk (or via MCP admin routes) before staff go-live.

## Company & warehouse

- [ ] Company configured with correct abbreviation (rental warehouse = `Main Store Floor - {abbr}`)
- [ ] Opening stock entered at Main Store Floor for qty items (sandbags, expendables)
- [ ] Warehouse containers transferred to correct locations (e.g. TRAY-004, CART-012)

## Items & serials

- [ ] Real Items created (not pilot/dev codes) with Item Groups, daily rates, serial flags
- [ ] Serial Nos created for all serialized equipment with correct item links
- [ ] Qty items (e.g. sandbags) have stock balance at rental warehouse

## Customers

- [ ] Production Customers entered with contact info and `id_document` where required
- [ ] Remove or ignore U2/U3 gate test clients if not needed for operations

## Users & roles

- [ ] ERPNext Users created for each staff member (replace any Supabase Auth accounts)
- [ ] **Sales User** role assigned: Customers + Equipment Rental read/write/submit
- [ ] Test login via Flutter with each role before go-live

## Rentals validation

- [ ] Create first production rental in Flutter (MCP-only build)
- [ ] Submit rental — serial overlap blocked (SERIAL_ALREADY_RENTED)
- [ ] Qty line blocked when stock insufficient (INSUFFICIENT_QTY)
- [ ] Return rental — status → Returned, serials released

## MCP & infra

- [ ] MCP server running with `ERPNEXT_URL`, API keys, `MCP_JWT_SECRET`
- [ ] Flutter runs with `--dart-define=MCP_BASE_URL` only (no Supabase)
- [ ] `flutter analyze` clean; zero Supabase references in `lib/`

## Gate

**Pass when:** First real rental created end-to-end in Flutter; ERPNext is sole ledger; no Supabase dependency in build.
