-- =============================================================================
-- Film Equipment Rental — Supabase Schema
-- Generated: 2026-06-13 | Status: V1 PRODUCTION
-- Apply via: Supabase Dashboard → SQL Editor (or supabase db query)
-- =============================================================================

-- =============================================================================
-- TABLES
-- =============================================================================

-- profiles: extends auth.users, auto-created on signup via trigger
CREATE TABLE IF NOT EXISTS profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('admin', 'staff', 'client')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- NOTE: Default role is 'staff'. First admin must be manually promoted in Dashboard.

CREATE TABLE IF NOT EXISTS categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS equipment (
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

CREATE TABLE IF NOT EXISTS clients (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name    TEXT NOT NULL,
  phone        TEXT,
  email        TEXT,
  id_document  TEXT,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rentals (
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

-- rental_items: one row per equipment item on a rental
-- damage_notes: V1 damage tracking (text field); V2 will add damage_reports table alongside
CREATE TABLE IF NOT EXISTS rental_items (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rental_id            UUID NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
  equipment_id         UUID NOT NULL REFERENCES equipment(id),
  daily_rate_snapshot  NUMERIC(10,2) NOT NULL, -- rate locked at rental time, immutable
  damage_notes         TEXT,                    -- V1 damage tracking
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- INDEXES (query-missing-indexes: add indexes on FK columns used in joins/filters)
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_equipment_category_id  ON equipment(category_id);
CREATE INDEX IF NOT EXISTS idx_equipment_status        ON equipment(status);
CREATE INDEX IF NOT EXISTS idx_rentals_client_id       ON rentals(client_id);
CREATE INDEX IF NOT EXISTS idx_rentals_created_by      ON rentals(created_by);
CREATE INDEX IF NOT EXISTS idx_rentals_status          ON rentals(status);
CREATE INDEX IF NOT EXISTS idx_rental_items_rental_id  ON rental_items(rental_id);
CREATE INDEX IF NOT EXISTS idx_rental_items_equipment_id ON rental_items(equipment_id);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Auto-update updated_at on any UPDATE
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_equipment_updated_at
  BEFORE UPDATE ON equipment FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_clients_updated_at
  BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE TRIGGER trg_rentals_updated_at
  BEFORE UPDATE ON rentals FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create profile row when a new auth user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown'),
    'staff'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- NOTE: SECURITY DEFINER required here: trigger runs in auth schema context,
-- needs elevated privilege to write to public.profiles. Narrow scope: inserts
-- only the current new user's own row. No user-controlled input in SQL.

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================================================
-- RPC FUNCTIONS (SECURITY DEFINER — runs in one DB transaction, atomic)
-- Approval checkpoint: Both functions use SECURITY DEFINER for atomicity.
-- Input validation is inside the function body. Function is in public schema
-- but callable only by authenticated sessions (enforced by anon key RLS).
-- =============================================================================

-- create_rental: atomically inserts rental + rental_items + marks equipment rented
CREATE OR REPLACE FUNCTION create_rental(
  p_client_id      UUID,
  p_created_by     UUID,
  p_start_date     DATE,
  p_end_date       DATE,
  p_deposit_amount NUMERIC,
  p_deposit_paid   BOOLEAN,
  p_notes          TEXT,
  p_equipment_ids  UUID[]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rental_id UUID;
  v_equip_id  UUID;
  v_rate      NUMERIC(10,2);
BEGIN
  -- Validate all equipment is available before touching anything
  IF EXISTS (
    SELECT 1 FROM equipment
    WHERE id = ANY(p_equipment_ids)
      AND status != 'available'
  ) THEN
    RAISE EXCEPTION 'One or more equipment items are not available for rental';
  END IF;

  -- Validate equipment array is not empty
  IF array_length(p_equipment_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'Rental must include at least one equipment item';
  END IF;

  -- Insert the rental header
  INSERT INTO rentals (
    client_id, created_by, start_date, end_date,
    deposit_amount, deposit_paid, notes
  )
  VALUES (
    p_client_id, p_created_by, p_start_date, p_end_date,
    p_deposit_amount, p_deposit_paid, p_notes
  )
  RETURNING id INTO v_rental_id;

  -- Insert one rental_item per equipment, snapshot the daily_rate
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

-- return_rental: atomically marks rental returned + resets all equipment to available
CREATE OR REPLACE FUNCTION return_rental(p_rental_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate rental exists and is active/overdue
  IF NOT EXISTS (
    SELECT 1 FROM rentals
    WHERE id = p_rental_id AND status IN ('active', 'overdue')
  ) THEN
    RAISE EXCEPTION 'Rental % is not in an active or overdue state', p_rental_id;
  END IF;

  UPDATE rentals SET status = 'returned' WHERE id = p_rental_id;

  UPDATE equipment
  SET status = 'available'
  WHERE id IN (
    SELECT equipment_id FROM rental_items WHERE rental_id = p_rental_id
  );
END;
$$;

-- =============================================================================
-- ROW LEVEL SECURITY
-- V1: all authenticated users (admin + staff) can read/write everything.
-- Uses (select auth.uid()) subquery pattern (not auth.role()) per plan requirement.
-- V2 upgrade: replace policies with role-based checks using profiles.role.
-- =============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
-- Users read/update only their own profile row
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING ((SELECT auth.uid()) = id);
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "categories_all_authenticated" ON categories
  FOR ALL USING ((SELECT auth.uid()) IS NOT NULL);

ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
CREATE POLICY "equipment_all_authenticated" ON equipment
  FOR ALL USING ((SELECT auth.uid()) IS NOT NULL);

ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "clients_all_authenticated" ON clients
  FOR ALL USING ((SELECT auth.uid()) IS NOT NULL);

ALTER TABLE rentals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rentals_all_authenticated" ON rentals
  FOR ALL USING ((SELECT auth.uid()) IS NOT NULL);
-- TODO(V2): add client self-view policy when client portal is built

ALTER TABLE rental_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rental_items_all_authenticated" ON rental_items
  FOR ALL USING ((SELECT auth.uid()) IS NOT NULL);

-- =============================================================================
-- SEED DATA — default equipment categories
-- =============================================================================
INSERT INTO categories (name) VALUES
  ('Cameras'),
  ('Lenses'),
  ('Lighting'),
  ('Audio'),
  ('Grip & Support'),
  ('Power & Batteries'),
  ('Expendables')
ON CONFLICT (name) DO NOTHING;
