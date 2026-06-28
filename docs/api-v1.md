# MCP API v1 — Contract

Single source of truth for Flutter ↔ `mcp-server` integration.  
Base URL: `{MCP_BASE_URL}/api/v1`  
Auth: `Authorization: Bearer <access_token>`

## Response envelope

Success:

```json
{ "ok": true, "data": {}, "error": null }
```

Error:

```json
{
  "ok": false,
  "data": null,
  "error": {
    "code": "SESSION_EXPIRED",
    "message": "Session expired — please log in again",
    "details": {}
  }
}
```

## Stable error codes

| Code | HTTP | When |
|---|---|---|
| `SESSION_EXPIRED` | 401 | ERPNext sid dead or JWT invalid |
| `UNAUTHORIZED` | 401 | Missing Bearer token or warehouse API key |
| `FORBIDDEN` | 403 | Role insufficient |
| `NOT_FOUND` | 404 | Item/customer/rental missing |
| `SERIAL_ALREADY_RENTED` | 409 | Double-book |
| `INSUFFICIENT_QTY` | 409 | Qty line exceeds stock |
| `VALIDATION_ERROR` | 422 | Bad input |
| `ERPNEXT_UNAVAILABLE` | 502 | Upstream failure |

## Auth

| Method | Path | Body | Response `data` |
|---|---|---|---|
| POST | `/auth/login` | `{ "username", "password" }` | `{ access_token, expires_in, user }` |
| POST | `/auth/logout` | — | `{ logged_out: true }` |
| GET | `/auth/me` | — | `{ name, email, roles }` |

## Items & inventory

| Method | Path | Query / Body | Response `data` |
|---|---|---|---|
| GET | `/items` | `group`, `has_serial` | `{ items: Item[] }` |
| GET | `/items/:item_code` | — | `{ item, serial_count, serials, qty_on_hand, rental_warehouse }` |
| GET | `/items/:item_code/serials` | — | `{ serials }` |
| GET | `/serials/:serial` | — | `{ serial }` |
| POST | `/items` | See below | `{ item }` |
| PATCH | `/items/:item_code` | See below | `{ item }` |
| POST | `/serials` | See below | `{ serial }` |

### POST `/items`

```json
{
  "item_code": "ARRI-LAMP-HEAD",
  "item_name": "Arri Lamp Head",
  "item_group": "Lighting",
  "standard_rate": 150,
  "has_serial_no": true,
  "serial_no": "LB-LAMP-0001"
}
```

| Field | Required | Notes |
|---|---|---|
| `item_code` | No | Slug from `item_name` if omitted |
| `item_name` | Yes | |
| `item_group` | Yes | ERPNext Item Group name |
| `standard_rate` | No | Daily rental rate |
| `has_serial_no` | No | Default `true` |
| `serial_no` | No | Creates Serial No at rental warehouse when set |

ERPNext defaults applied server-side: `stock_uom=Nos`, `is_stock_item=1`, `maintain_stock=1`.

### PATCH `/items/:item_code`

```json
{
  "item_name": "Arri Lamp Head (rev B)",
  "item_group": "Lighting",
  "standard_rate": 175,
  "disabled": 0
}
```

### POST `/serials`

```json
{
  "serial_no": "LB-LAMP-0042",
  "item_code": "ARRI-LAMP-HEAD",
  "warehouse": "Main Store Floor - LB"
}
```

| Field | Required | Notes |
|---|---|---|
| `serial_no` | Yes | Barcode = serial name |
| `item_code` | Yes | Must exist |
| `warehouse` | No | Default rental warehouse for company |

## Customers

| Method | Path | Body | Response `data` |
|---|---|---|---|
| GET | `/customers` | — | `{ customers }` |
| GET | `/customers/:name` | — | `{ customer }` |
| POST | `/customers` | See below | `{ customer }` |
| PATCH | `/customers/:name` | See below | `{ customer }` |

### POST `/customers`

```json
{
  "customer_name": "Jane Production LLC",
  "mobile_no": "+1 555 0100",
  "email_id": "jane@example.com",
  "id_document": "DL-12345"
}
```

Defaults: `customer_type=Individual`, `customer_group=Individual`, `territory=All Territories`.

### PATCH `/customers/:name`

```json
{
  "customer_name": "Jane Production LLC",
  "mobile_no": "+1 555 0100",
  "email_id": "jane@example.com",
  "id_document": "DL-12345"
}
```

## Rentals

| Method | Path | Body | Response `data` |
|---|---|---|---|
| GET | `/rentals` | — | `{ rentals }` — filters: `status`, `customer` |
| GET | `/rentals/:name` | — | `{ rental }` incl. `items` child rows |
| POST | `/rentals` | See below | `{ rental }` — Draft |
| PATCH | `/rentals/:name` | See below | `{ rental }` — Draft only |
| POST | `/rentals/:name/submit` | — | `{ rental }` — Active; atomic availability check |
| POST | `/rentals/:name/return` | — | `{ rental }` — Returned |
| PATCH | `/rentals/:name/lines/:idx/damage` | `{ damage_notes }` | `{ rental }` |

### POST `/rentals`

```json
{
  "customer": "Jane Production LLC",
  "start_date": "2026-06-28",
  "end_date": "2026-06-30",
  "deposit_amount": 500,
  "deposit_paid": true,
  "notes": "Pickup at 9am",
  "items": [
    {
      "line_type": "serialized",
      "item_code": "ARRI-LAMP-HEAD",
      "serial_no": "LB-LAMP-0001",
      "qty": 1,
      "daily_rate_snapshot": 150
    },
    {
      "line_type": "qty",
      "item_code": "SANDBAG-25LB",
      "qty": 4,
      "daily_rate_snapshot": 5
    }
  ]
}
```

| Field | Required | Notes |
|---|---|---|
| `customer` | Yes | ERPNext Customer name |
| `start_date` / `end_date` | Yes | ISO date `YYYY-MM-DD` |
| `items` | Yes | Min 1 line; see line schema |
| `deposit_amount` | No | Default `0` |
| `deposit_paid` | No | Default `false` |
| `notes` | No | |

**Line schema**

| Field | Required | When |
|---|---|---|
| `line_type` | Yes | `serialized` or `qty` |
| `item_code` | Yes | ERPNext Item |
| `serial_no` | Yes if serialized | Barcode |
| `qty` | Yes if qty | Float > 0; serialized lines forced to `1` |
| `daily_rate_snapshot` | No | Locked at submit from Item if omitted |

### PATCH `/rentals/:name`

Same header fields as POST (all optional). Replaces `items` when `items` array is sent. Only Draft (`docstatus=0`).

### POST `/rentals/:name/submit`

Idempotent: second submit on already-submitted doc returns current state.

Errors: `SERIAL_ALREADY_RENTED` (409), `INSUFFICIENT_QTY` (409).

### PATCH `/rentals/:name/lines/:idx/damage`

`idx` = ERPNext child row index (1-based). Body: `{ "damage_notes": "..." }`.


## Dashboard

| Method | Path | Response `data` |
|---|---|---|
| GET | `/dashboard/stats` | `{ active_rentals, overdue_rentals, available_serialized, item_count }` |

## Warehouse (v1 aliases)

Same bodies as legacy routes; wrapped in `{ ok, data, error }` envelope. Requires `X-Api-Key` header when `MCP_API_KEY` is set on the server (JWT not used).

| Method | Path | Body | Response `data` |
|---|---|---|---|
| POST | `/warehouse/audit` | `{ "container_barcode": "TRAY-004" }` | `{ label, container_barcode, warehouse, expected, actual, missing, surplus, not_tracked_v1 }` |
| POST | `/warehouse/session/start` | `{ "mode": "dispatch"\|"return", "source_barcode", "destination_barcode" }` | `{ session_id, mode, expected_audited, not_tracked_v1, source_warehouse, dest_warehouse, source_label, destination_label }` |
| POST | `/warehouse/session/scan` | `{ "session_id", "serial" }` | `{ serial, item_code, warehouse, duplicate, scanned_count }` |
| POST | `/warehouse/session/end` | `{ "session_id" }` | `{ scanned, missing, unexpected, complete }` |
| POST | `/warehouse/session/confirm` | `{ "session_id", "proceed_anyway"?, "reason"? }` | `{ stock_entry_id, items_moved }` |

Legacy aliases (unchanged for scanner-web): `/api/audit_container`, `/api/start_session`, etc.

## Flutter compile-time config

```bash
flutter run \
  --dart-define=MCP_BASE_URL=http://localhost:3001 \
  --dart-define=MCP_API_VERSION=v1 \
  --dart-define=MCP_API_KEY=your-key   # optional — when MCP server requires X-Api-Key
```
