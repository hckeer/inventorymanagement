# Local dev runbook — full stack + Android phone

## Architecture (your machine)

| Service | URL | Notes |
|---------|-----|-------|
| ERPNext | http://localhost:8080 | Docker `frappe_docker`, site `frontend` |
| MCP | http://localhost:3001 | Phone uses **LAN IP** (see below) |
| Flutter | Android device | Talks to MCP only |

**Critical:** On your phone, `localhost` is the phone itself. Flutter must use your PC's LAN IP:

```
MCP_BASE_URL=http://192.168.1.74:3001   # example — run: hostname -I
```

Phone and PC must be on the same Wi‑Fi (you are: PC `192.168.1.74`, phone `192.168.1.64`).

---

## One-time setup

### 1. ERPNext (Docker)

```bash
cd /home/hckeer/work/erpnest/frappe_docker
docker compose -f pwd.yml up -d db redis-cache redis-queue backend frontend websocket queue-short queue-long scheduler
```

Verify:

```bash
curl http://localhost:8080/api/method/ping
# → {"message":"pong"}
```

Login: http://localhost:8080 — `Administrator` / `admin`

### 2. Sync Frappe app (after schema changes)

```bash
docker cp /home/hckeer/work/inventorymanagement/lightbenders_warehouse/. \
  frappe_docker-backend-1:/home/frappe/frappe-bench/apps/lightbenders_warehouse/
docker exec frappe_docker-backend-1 bench --site frontend migrate
docker exec frappe_docker-backend-1 bench --site frontend execute \
  lightbenders_warehouse.setup.custom_fields.ensure_customer_id_document
```

### 3. MCP server

```bash
cd /home/hckeer/work/inventorymanagement/mcp-server
cp .env.example .env   # if needed — .env already has ERPNEXT_URL, keys, JWT secret
npm install
npm run dev
```

Verify:

```bash
curl http://localhost:3001/health
# → {"status":"ok","service":"lightbenders-mcp-server"}
```

From phone network (optional):

```bash
curl http://192.168.1.74:3001/health
```

### 4. Android wireless debugging

Debian's system `adb` (v29) is too old — use Google platform-tools:

```bash
make adb-install   # once — installs ~/Android/platform-tools/adb v37+
export PATH="$HOME/Android/platform-tools:$PATH"
```

On phone: **Settings → Developer options → Wireless debugging**

**Step A — Pair (one-time per session):**

Tap **"Pair device with pairing code"**. Note:
- Pairing address (e.g. `192.168.1.64:44455`)
- **6-digit code** (changes each time)

```bash
~/Android/platform-tools/adb pair 192.168.1.64:44455
# enter 6-digit code when prompted

# or non-interactive:
make adb-pair PAIR_CODE=123456 PAIR_PORT=44455
```

**Step B — Connect:**

On the main **Wireless debugging** screen (not the pair dialog), note IP:port (e.g. `192.168.1.64:38521`):

```bash
make adb-connect CONNECT_PORT=38521
# or: ~/Android/platform-tools/adb connect 192.168.1.64:38521
make devices
```

---

## Daily workflow

```bash
# Terminal 1 — MCP (keep running)
cd /home/hckeer/work/inventorymanagement/mcp-server && npm run dev

# Terminal 2 — Flutter to phone
cd /home/hckeer/work/inventorymanagement
make health      # ERPNext + MCP up?
make devices     # phone connected?
make run         # builds with LAN MCP URL auto-detected
```

Manual flutter run (replace IP if different):

```bash
/home/hckeer/flutter/bin/flutter run \
  --dart-define=MCP_BASE_URL=http://192.168.1.74:3001 \
  --dart-define=MCP_API_VERSION=v1
```

---

## Test checklist (full app)

1. **Login** — ERPNext user (`Administrator` / `admin` or Sales User)
2. **Dashboard** — stats load
3. **Equipment** — list, detail (serials + qty), create/edit item
4. **Clients** — list, create/edit customer
5. **Rentals** — hybrid lines (serial + qty), submit, return, damage notes
6. **Warehouse** — Audit `TRAY-004` → "all good" (match scanner-web)
7. **Warehouse** — Dispatch/Return session (optional)

Production seed before go-live: `docs/u4-production-seed-checklist.md`

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Flutter "Network error" on phone | Use LAN IP in `MCP_BASE_URL`, not `localhost` |
| MCP unreachable from phone | MCP listens on `0.0.0.0:3001`; check PC firewall allows 3001 |
| Session expired | Re-login; MCP JWT TTL in `.env` |
| `adb connect` refused | Pair first; use **connect** port not pairing port |
| ERPNext 502 | `docker ps` — wait for backend/frontend healthy |
| Cleartext HTTP blocked | `android:usesCleartextTraffic="true"` in AndroidManifest (dev) |

---

## scanner-web (optional, iPad/browser)

```bash
cd /home/hckeer/work/inventorymanagement/scanner-web
npm install && npm run dev
# VITE_MCP_URL=http://localhost:3001
```

Compare TRAY-004 audit with Flutter Warehouse tab.
