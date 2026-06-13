# Film Equipment Inventory — Architecture Plan
> Generated: 2026-06-13 | Last revised: 2026-06-13 (v2) | Status: PLANNING PHASE — no code written yet

---

## CHANGELOG v2
| # | Change | Reason |
|---|---|---|
| 1 | Cut `damage_reports` table + model + repo | Replaced with `damage_notes TEXT` on `rental_items`. Zero extra infra for same V1 value. |
| 2 | Simplified RLS to `authenticated`-only for V1 | No client logins in V1. All users are admin/staff. `profiles.role` column kept for V2 upgrade. |
| 3 | Removed `uuid` package | Supabase generates all UUIDs via `gen_random_uuid()`. Never needed in Flutter. |
| 4 | Removed `riverpod_annotation`, `riverpod_generator`, `build_runner` | Code-gen adds build steps, stale-file bugs, and CI friction. Manual providers are 15 lines each. |
| 5 | Replaced `flutter_dotenv` with `--dart-define` | Zero runtime code, no asset file, keys baked into binary, nothing to commit accidentally. |
| 6 | Pinned all dependency versions (removed `^`) | Prevents silent breaking changes on a mid-build pub upgrade. |
| 7 | Defined `RentalHistoryEntry` typed model | Replaces `Map<String, dynamic>` return type. No dynamic types where a shape is known. |
| 8 | Added `create_rental` Supabase RPC for atomic rental creation | Rental + rental_items insert + equipment status updates happen in one DB transaction. No partial state. |

---

## REQUIREMENTS SUMMARY

| Topic | Decision |
|---|---|
| Categories | Cameras, Lenses, Lighting, Audio, Grip/Support, Power/Batteries, Expendables + custom |
| Rental unit | Day-based |
| Item exclusivity | One item → one client at a time (exclusive) |
| Damage tracking | `damage_notes TEXT` on `rental_items` (V1). Full `damage_reports` table in V2. |
| Users | Schema: Admin / Staff / Client roles. V1 app: Admin + Staff only log in. Client = data record only. |
| Client DB | Full profile (name, phone, email, ID/document) |
| Rental history | Full per-item history (who, when, damage notes, revenue) |
| Barcode/QR | V2 (deferred) |
| Offline | V2 (deferred — always-online for V1) |
| V1 Screens | Equipment List, Create/Edit Rental, Client DB, Equipment Detail, Dashboard, Rental History |
| V2 Defer | Client login portal, Staff role UI, Reports/charts, PDF invoices, Push notifications, Damage photo upload, Expendables tracking, QR scanning, Offline sync |

---

## STEP 1 — SKILL AUDIT

### Skills available in skills.sh (to be verified against actual file):
| Skill | Handles |
|---|---|
| `flutter_model` | Generates model class with fromJson/toJson |
| `flutter_repo` | Generates repository class with Supabase queries |
| `flutter_provider` | Generates Riverpod provider wiring |
| `flutter_screen` | Generates screen scaffold with loading/error/success states |
| `flutter_widget` | Generates reusable widget |
| `supabase_schema` | Generates SQL schema + RLS policies |
| `flutter_nav` | Generates GoRouter navigation setup |

### Gaps flagged (no skill covers these — writing raw with human approval):
- `supabase_rpc` — Postgres function `create_rental(...)` for atomic transaction. **FLAG: No skill. Writing raw SQL. Needs explicit approval.**
- `flutter_form_validation` — inline form validators on rental/equipment forms. **FLAG: Writing inline, simple, no abstraction.**

> **Human approval checkpoint:** The two items marked FLAG above need go-ahead before those files are written.

---

## STEP 2 — CLAUDE.md STATUS

- [x] `CLAUDE.md` exists at project root
- [ ] Flutter-specific conventions **not yet appended** — will be added before first file is written
- Planned additions: naming conventions, folder structure rules, Riverpod manual-provider patterns, null safety rules, `--dart-define` usage note

---

## STEP 3 — ARCHITECTURE PLAN

---

### 3A — FOLDER STRUCTURE (`lib/`)

```
lib/
├── main.dart                          # App entry, Supabase init, ProviderScope
├── app.dart                           # MaterialApp.router + GoRouter setup
│
├── core/
│   ├── supabase_client.dart           # Supabase singleton + client accessor
│   ├── constants.dart                 # Table names, status enums, env key reads
│   ├── extensions.dart                # DateTime formatters, String helpers
│   └── error_handler.dart             # Unified Supabase error → human-readable string
│
├── models/
│   ├── user_profile.dart              # UserProfile (id, fullName, role)
│   ├── category.dart                  # Category (id, name, createdAt)
│   ├── equipment.dart                 # Equipment (id, name, categoryId, status, dailyRate, serialNo, notes)
│   ├── client.dart                    # Client (id, fullName, phone, email, idDocument, notes)
│   ├── rental.dart                    # Rental (id, clientId, createdBy, startDate, endDate, status, depositAmount, depositPaid, notes)
│   ├── rental_item.dart               # RentalItem (id, rentalId, equipmentId, dailyRateSnapshot, damageNotes)
│   └── rental_history_entry.dart      # RentalHistoryEntry — typed join of rental + client for equipment history view
│
├── repositories/
│   ├── auth_repository.dart           # signIn, signOut, watchAuthState, getCurrentUserProfile
│   ├── category_repository.dart       # getAll, create, update, delete
│   ├── equipment_repository.dart      # getAll, getById, create, update, delete, getRentalHistory
│   ├── client_repository.dart         # getAll, getById, create, update
│   ├── rental_repository.dart         # getAll, getById, createViaRpc, update, markReturned
│   └── rental_item_repository.dart    # getByRental, updateDamageNotes
│
├── providers/
│   ├── auth_provider.dart             # authStateProvider, currentUserProfileProvider
│   ├── category_provider.dart         # categoriesProvider (AsyncNotifier)
│   ├── equipment_provider.dart        # equipmentListProvider (AsyncNotifier), equipmentDetailProvider.family
│   ├── client_provider.dart           # clientListProvider (AsyncNotifier), clientDetailProvider.family
│   ├── rental_provider.dart           # rentalListProvider (AsyncNotifier), rentalDetailProvider.family
│   └── dashboard_provider.dart        # dashboardStatsProvider (FutureProvider)
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── auth_guard.dart            # GoRouter redirect if not authenticated
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── equipment/
│   │   ├── equipment_list_screen.dart
│   │   ├── equipment_detail_screen.dart
│   │   └── equipment_form_screen.dart  # Create / Edit
│   ├── clients/
│   │   ├── client_list_screen.dart
│   │   ├── client_detail_screen.dart
│   │   └── client_form_screen.dart
│   └── rentals/
│       ├── rental_list_screen.dart
│       ├── rental_detail_screen.dart
│       └── rental_form_screen.dart
│
└── widgets/
    ├── status_badge.dart               # Colored chip: available / rented / maintenance / retired
    ├── app_loading.dart                # Centered CircularProgressIndicator
    ├── app_error.dart                  # Error message + retry button
    ├── app_empty.dart                  # Empty state with icon + message
    ├── equipment_card.dart             # Equipment item card for list
    ├── rental_card.dart                # Rental summary card for list
    └── client_tile.dart                # Client row tile for list
```

**Removed from original plan:**
- `lib/models/damage_report.dart` — cut. Field lives on `rental_items`.
- `lib/repositories/damage_repository.dart` — cut.

---

### 3B — SUPABASE SCHEMA

#### Table: `profiles`
Extends `auth.users`. Auto-created via trigger on signup. `role` column kept for V2 role-based access.

```sql
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('admin', 'staff', 'client')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- NOTE: Default role is 'staff' so new signups are not accidental admins.
-- First user must be manually promoted to 'admin' in Supabase dashboard.
```

#### Table: `categories`

```sql
CREATE TABLE categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### Table: `equipment`

```sql
CREATE TABLE equipment (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,
  category_id  UUID NOT NULL REFERENCES categories(id),
  status       TEXT NOT NULL DEFAULT 'available'
                 CHECK (status IN ('available', 'rented', 'maintenance', 'retired')),
  daily_rate   NUMERIC(10,2) NOT NULL,
  serial_no    TEXT,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### Table: `clients`

```sql
CREATE TABLE clients (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name    TEXT NOT NULL,
  phone        TEXT,
  email        TEXT,
  id_document  TEXT,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### Table: `rentals`

```sql
CREATE TABLE rentals (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id      UUID NOT NULL REFERENCES clients(id),
  created_by     UUID NOT NULL REFERENCES profiles(id),
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL,
  status         TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'returned', 'overdue', 'cancelled')),
  deposit_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  deposit_paid   BOOLEAN NOT NULL DEFAULT FALSE,
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT end_after_start CHECK (end_date >= start_date)
);
```

#### Table: `rental_items`
Each row = one piece of equipment on one rental.
`damage_notes` replaces the full `damage_reports` table for V1.

```sql
CREATE TABLE rental_items (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rental_id            UUID NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
  equipment_id         UUID NOT NULL REFERENCES equipment(id),
  daily_rate_snapshot  NUMERIC(10,2) NOT NULL,  -- rate locked at rental time, never changes
  damage_notes         TEXT,                     -- V1 damage tracking: simple text field
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

> **V2 migration note**: When `damage_reports` table is added in V2, `damage_notes` column stays and both coexist. No destructive migration needed.

---

#### Triggers

**Auto-update `updated_at`:**

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_equipment_updated_at
  BEFORE UPDATE ON equipment FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_clients_updated_at
  BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_rentals_updated_at
  BEFORE UPDATE ON rentals FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

**Auto-create profile on signup:**

```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown'),
    'staff'  -- default; promote to admin manually
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

---

#### Supabase RPC — `create_rental` (atomic rental creation)

**Why RPC:** Creating a rental involves 3 operations that must succeed or fail together:
1. Insert into `rentals`
2. Insert N rows into `rental_items`
3. Update all involved `equipment` rows to `status = 'rented'`

Sequential REST calls can leave data inconsistent (e.g. rental created, equipment status not updated if app crashes). A single Postgres function runs in one transaction with automatic rollback.

```sql
CREATE OR REPLACE FUNCTION create_rental(
  p_client_id      UUID,
  p_created_by     UUID,
  p_start_date     DATE,
  p_end_date       DATE,
  p_deposit_amount NUMERIC,
  p_deposit_paid   BOOLEAN,
  p_notes          TEXT,
  p_equipment_ids  UUID[]   -- array of equipment UUIDs to add
)
RETURNS UUID   -- returns the new rental's id
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rental_id UUID;
  v_equip_id  UUID;
  v_rate      NUMERIC(10,2);
BEGIN
  -- Validate all equipment is available
  IF EXISTS (
    SELECT 1 FROM equipment
    WHERE id = ANY(p_equipment_ids)
      AND status != 'available'
  ) THEN
    RAISE EXCEPTION 'One or more equipment items are not available for rental';
  END IF;

  -- Insert rental
  INSERT INTO rentals (
    client_id, created_by, start_date, end_date,
    deposit_amount, deposit_paid, notes
  )
  VALUES (
    p_client_id, p_created_by, p_start_date, p_end_date,
    p_deposit_amount, p_deposit_paid, p_notes
  )
  RETURNING id INTO v_rental_id;

  -- Insert rental_items (one per equipment, snapshot the daily_rate)
  FOREACH v_equip_id IN ARRAY p_equipment_ids LOOP
    SELECT daily_rate INTO v_rate FROM equipment WHERE id = v_equip_id;

    INSERT INTO rental_items (rental_id, equipment_id, daily_rate_snapshot)
    VALUES (v_rental_id, v_equip_id, v_rate);
  END LOOP;

  -- Mark all equipment as rented
  UPDATE equipment
  SET status = 'rented'
  WHERE id = ANY(p_equipment_ids);

  RETURN v_rental_id;
END;
$$;
```

**Return rental RPC** (also atomic — marks rental returned + resets equipment status):

```sql
CREATE OR REPLACE FUNCTION return_rental(p_rental_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update rental status
  UPDATE rentals SET status = 'returned' WHERE id = p_rental_id;

  -- Free all equipment on this rental
  UPDATE equipment
  SET status = 'available'
  WHERE id IN (
    SELECT equipment_id FROM rental_items WHERE rental_id = p_rental_id
  );
END;
$$;
```

---

#### RLS POLICIES (V1: simplified to `authenticated`)

**Rationale:** All V1 users are admin or staff (clients don't log in). RLS simply checks the user has a valid session. Role-based policies are a V2 upgrade when client login is built.

```sql
-- profiles: users can read/update their own row only
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid());

-- categories: any authenticated user can read/write
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "categories_all" ON categories FOR ALL USING (auth.role() = 'authenticated');

-- equipment: any authenticated user can read/write
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
CREATE POLICY "equipment_all" ON equipment FOR ALL USING (auth.role() = 'authenticated');

-- clients: any authenticated user can read/write
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "clients_all" ON clients FOR ALL USING (auth.role() = 'authenticated');

-- rentals: any authenticated user can read/write
ALTER TABLE rentals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rentals_all" ON rentals FOR ALL USING (auth.role() = 'authenticated');
-- TODO(aym): V2 — add client self-view policy when client portal is built

-- rental_items: any authenticated user can read/write
ALTER TABLE rental_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rental_items_all" ON rental_items FOR ALL USING (auth.role() = 'authenticated');
```

> **V2 upgrade path:** Replace `authenticated` policies with role-checked policies using `profiles.role`. Schema already has the column. Zero migration needed.

---

### 3C — SCREEN MAP

| Screen | Purpose | Data In | Data Out |
|---|---|---|---|
| `LoginScreen` | Email/password auth | email, password | JWT session → navigate to Dashboard |
| `DashboardScreen` | Overview stats | active count, overdue count, today revenue | navigate to any section |
| `EquipmentListScreen` | Browse + filter equipment | category filter, status filter, search text | → EquipmentDetailScreen / EquipmentFormScreen |
| `EquipmentDetailScreen` | Item info + full rental history | `equipment_id` | Equipment + `List<RentalHistoryEntry>` |
| `EquipmentFormScreen` | Create / Edit equipment | optional `equipment_id` | saved Equipment → pop |
| `ClientListScreen` | Browse + search clients | search text | → ClientDetailScreen / ClientFormScreen |
| `ClientDetailScreen` | Client profile + rental list | `client_id` | Client + `List<Rental>` |
| `ClientFormScreen` | Create / Edit client | optional `client_id` | saved Client → pop |
| `RentalListScreen` | All rentals filterable by status | status filter | → RentalDetailScreen / RentalFormScreen |
| `RentalDetailScreen` | Rental info + items + damage notes | `rental_id` | Rental + `List<RentalItem>` |
| `RentalFormScreen` | Create rental (select client + equipment + dates) | optional `rental_id` | calls `create_rental` RPC → pop |

---

### 3D — NAVIGATION TREE (GoRouter)

```
/login
/                          → redirect to /dashboard (AuthGuard wraps shell)
/dashboard
/equipment
  /equipment/new
  /equipment/:id
  /equipment/:id/edit
/clients
  /clients/new
  /clients/:id
  /clients/:id/edit
/rentals
  /rentals/new
  /rentals/:id
  /rentals/:id/edit        (edit = update damage notes, extend dates, cancel)
```

Shell route (`ShellRoute`) wraps `/dashboard`, `/equipment`, `/clients`, `/rentals` with a persistent `NavigationBar` at bottom.

---

### 3E — RIVERPOD PROVIDERS (manual — no code generation)

| Provider | Type | Purpose |
|---|---|---|
| `supabaseClientProvider` | `Provider<SupabaseClient>` | Exposes initialized Supabase client |
| `authStateProvider` | `StreamProvider<AuthState>` | Watches Supabase auth stream |
| `currentUserProfileProvider` | `FutureProvider<UserProfile?>` | Loads profile row for current user |
| `categoriesProvider` | `AsyncNotifier<List<Category>>` | All categories + CRUD mutations |
| `equipmentListProvider` | `AsyncNotifier<List<Equipment>>` | All equipment, filterable, with CRUD |
| `equipmentDetailProvider` | `FutureProvider.family<Equipment, String>` | Single equipment + history by ID |
| `rentalHistoryProvider` | `FutureProvider.family<List<RentalHistoryEntry>, String>` | Equipment rental history by equipment ID |
| `clientListProvider` | `AsyncNotifier<List<Client>>` | All clients, searchable, with CRUD |
| `clientDetailProvider` | `FutureProvider.family<Client, String>` | Single client by ID |
| `rentalListProvider` | `AsyncNotifier<List<Rental>>` | All rentals, filterable by status |
| `rentalDetailProvider` | `FutureProvider.family<Rental, String>` | Single rental + items by ID |
| `dashboardStatsProvider` | `FutureProvider<DashboardStats>` | Computed stats (active, overdue, revenue) |

---

### 3F — REPOSITORY CONTRACTS (signatures only — no implementation yet)

#### `AuthRepository`
```dart
Future<AuthResponse> signIn({required String email, required String password});
Future<void> signOut();
Stream<AuthState> watchAuthState();
Future<UserProfile?> getCurrentUserProfile();
```

#### `CategoryRepository`
```dart
Future<List<Category>> getAll();
Future<Category> create({required String name});
Future<Category> update({required String id, required String name});
Future<void> delete({required String id});
```

#### `EquipmentRepository`
```dart
Future<List<Equipment>> getAll({String? categoryId, String? status});
Future<Equipment> getById({required String id});
Future<Equipment> create({required Equipment equipment});
Future<Equipment> update({required Equipment equipment});
Future<void> delete({required String id});
// Returns typed history — no Map<String, dynamic>
Future<List<RentalHistoryEntry>> getRentalHistory({required String equipmentId});
```

#### `ClientRepository`
```dart
Future<List<Client>> getAll({String? searchQuery});
Future<Client> getById({required String id});
Future<Client> create({required Client client});
Future<Client> update({required Client client});
```

#### `RentalRepository`
```dart
Future<List<Rental>> getAll({String? status});
Future<Rental> getById({required String id});
// Delegates to create_rental RPC — atomic, no partial state possible
Future<String> createViaRpc({
  required String clientId,
  required DateTime startDate,
  required DateTime endDate,
  required List<String> equipmentIds,
  required double depositAmount,
  required bool depositPaid,
  String? notes,
});
Future<Rental> update({required Rental rental});
// Delegates to return_rental RPC — atomic equipment status reset
Future<void> markReturnedViaRpc({required String rentalId});
```

#### `RentalItemRepository`
```dart
Future<List<RentalItem>> getByRental({required String rentalId});
// Used to save damage notes after return
Future<void> updateDamageNotes({required String rentalItemId, required String notes});
```

---

### 3G — `RentalHistoryEntry` Model (typed join)

This model represents one row of a rental history query: a join of `rental_items` + `rentals` + `clients`, scoped to a single `equipment_id`.

```dart
class RentalHistoryEntry {
  final String rentalId;
  final String rentalItemId;
  final String clientName;        // from clients.full_name
  final DateTime startDate;       // from rentals.start_date
  final DateTime endDate;         // from rentals.end_date
  final String rentalStatus;      // from rentals.status
  final double dailyRateSnapshot; // from rental_items.daily_rate_snapshot
  final String? damageNotes;      // from rental_items.damage_notes
}
```

Query shape (Supabase):
```dart
supabase
  .from('rental_items')
  .select('id, daily_rate_snapshot, damage_notes, rental:rentals(id, start_date, end_date, status, client:clients(full_name))')
  .eq('equipment_id', equipmentId)
  .order('created_at', ascending: false);
```

---

## STEP 4 — BUILD ORDER

Files written in this exact sequence. `[ ]` = pending, `[x]` = done.

```
Phase 0 — Foundation
  [ ] 0.1  CLAUDE.md              Append Flutter-specific conventions
  [ ] 0.2  pubspec.yaml           Add pinned dependencies
  [ ] 0.3  supabase/schema.sql    Full schema + triggers + RPC functions + RLS

Phase 1 — Core
  [ ] 1.1  lib/core/supabase_client.dart
  [ ] 1.2  lib/core/constants.dart
  [ ] 1.3  lib/core/error_handler.dart
  [ ] 1.4  lib/core/extensions.dart

Phase 2 — Models
  [ ] 2.1  lib/models/user_profile.dart
  [ ] 2.2  lib/models/category.dart
  [ ] 2.3  lib/models/equipment.dart
  [ ] 2.4  lib/models/client.dart
  [ ] 2.5  lib/models/rental.dart
  [ ] 2.6  lib/models/rental_item.dart
  [ ] 2.7  lib/models/rental_history_entry.dart

Phase 3 — Repositories
  [ ] 3.1  lib/repositories/auth_repository.dart
  [ ] 3.2  lib/repositories/category_repository.dart
  [ ] 3.3  lib/repositories/equipment_repository.dart
  [ ] 3.4  lib/repositories/client_repository.dart
  [ ] 3.5  lib/repositories/rental_repository.dart
  [ ] 3.6  lib/repositories/rental_item_repository.dart

Phase 4 — Providers
  [ ] 4.1  lib/providers/auth_provider.dart
  [ ] 4.2  lib/providers/category_provider.dart
  [ ] 4.3  lib/providers/equipment_provider.dart
  [ ] 4.4  lib/providers/client_provider.dart
  [ ] 4.5  lib/providers/rental_provider.dart
  [ ] 4.6  lib/providers/dashboard_provider.dart

Phase 5 — Navigation + Entry
  [ ] 5.1  lib/app.dart            GoRouter + ShellRoute + AuthGuard redirect
  [ ] 5.2  lib/main.dart           Supabase.init + ProviderScope + runApp

Phase 6 — Shared Widgets
  [ ] 6.1  lib/widgets/app_loading.dart
  [ ] 6.2  lib/widgets/app_error.dart
  [ ] 6.3  lib/widgets/app_empty.dart
  [ ] 6.4  lib/widgets/status_badge.dart
  [ ] 6.5  lib/widgets/equipment_card.dart
  [ ] 6.6  lib/widgets/rental_card.dart
  [ ] 6.7  lib/widgets/client_tile.dart

Phase 7 — Screens
  [ ] 7.1  lib/screens/auth/login_screen.dart
  [ ] 7.2  lib/screens/auth/auth_guard.dart
  [ ] 7.3  lib/screens/dashboard/dashboard_screen.dart
  [ ] 7.4  lib/screens/equipment/equipment_list_screen.dart
  [ ] 7.5  lib/screens/equipment/equipment_detail_screen.dart
  [ ] 7.6  lib/screens/equipment/equipment_form_screen.dart
  [ ] 7.7  lib/screens/clients/client_list_screen.dart
  [ ] 7.8  lib/screens/clients/client_detail_screen.dart
  [ ] 7.9  lib/screens/clients/client_form_screen.dart
  [ ] 7.10 lib/screens/rentals/rental_list_screen.dart
  [ ] 7.11 lib/screens/rentals/rental_detail_screen.dart
  [ ] 7.12 lib/screens/rentals/rental_form_screen.dart
```

**Total: 32 files** (down from 34 — removed damage_report.dart and damage_repository.dart)

---

## OPEN QUESTIONS — MUST ANSWER BEFORE BUILD STARTS

1. **Flutter project scaffold**: Run  flutter create  *(No files exist in the project directory yet besides CLAUDE.md and plan.md)*

2. **Supabase project**: 


3. **RPC approval**: The `create_rental` and `return_rental` Postgres functions involve `SECURITY DEFINER`. This means they run with the permissions of the function owner (postgres role), bypassing RLS. Is this acceptable for V1? *(Standard pattern for atomic operations; the functions still validate input)*

4. **Supabase SQL — `auth.role()` deprecation**: In newer Supabase versions, `auth.role()` is deprecated in favor of `(SELECT role FROM auth.users WHERE id = auth.uid())`. Confirm which Supabase version your project is on, or I'll use the safe `auth.uid()` pattern only.

Use safe auth.uid() i guess. 

---

## DEPENDENCY LIST (pinned, no `^`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: 2.8.4       # Supabase client + auth + realtime
  flutter_riverpod: 2.6.1       # State management (manual providers, no codegen)
  go_router: 14.6.3             # Declarative navigation + ShellRoute
  intl: 0.20.2                  # Date formatting

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 5.0.0          # Linting rules
```

**5 runtime dependencies.** Nothing else.

### Secrets — `--dart-define` (no package needed)
```bash
# Run command (add to a local shell alias or Makefile):
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

```dart
// In code (zero runtime overhead, compile-time constant):
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

---

*Plan is locked. Next action: answer the 4 open questions above, then build starts at Phase 0.*
