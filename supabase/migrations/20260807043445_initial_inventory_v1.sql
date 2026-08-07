-- Inventory V1 replaces the legacy equipment schema. Existing public inventory
-- data is intentionally discarded; auth.users remains managed by Supabase Auth.

drop function if exists public.return_rental(uuid);
drop function if exists public.create_rental(uuid, uuid, date, date, numeric, boolean, text, uuid[]);
drop function if exists public.handle_new_user();
drop function if exists public.update_updated_at();

drop table if exists public.rental_items cascade;
drop table if exists public.rentals cascade;
drop table if exists public.equipment cascade;
drop table if exists public.clients cascade;
drop table if exists public.categories cascade;
drop table if exists public.profiles cascade;

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table public.manufacturers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sku text unique,
  category_id uuid references public.categories(id) on delete set null,
  manufacturer_id uuid references public.manufacturers(id) on delete set null,
  tracking_mode text not null check (tracking_mode in ('serialized', 'quantity')),
  daily_rate numeric(12, 2) not null default 0 check (daily_rate >= 0),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.product_identifiers (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  identifier text not null unique,
  identifier_type text not null check (identifier_type in ('ean_13', 'upc_a', 'internal')),
  created_at timestamptz not null default now()
);

create table public.assets (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  asset_id text not null unique,
  manufacturer_serial text unique,
  internal_qr text unique,
  status text not null default 'available'
    check (status in ('available', 'reserved', 'rented', 'maintenance', 'retired')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stock_balances (
  product_id uuid primary key references public.products(id) on delete cascade,
  on_hand_quantity integer not null default 0 check (on_hand_quantity >= 0),
  reserved_quantity integer not null default 0 check (reserved_quantity >= 0),
  rented_quantity integer not null default 0 check (rented_quantity >= 0),
  updated_at timestamptz not null default now(),
  check (reserved_quantity + rented_quantity <= on_hand_quantity)
);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  email text,
  id_document text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.rentals (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  start_date date not null,
  end_date date not null,
  status text not null default 'reserved'
    check (status in ('reserved', 'active', 'returned', 'cancelled')),
  deposit_amount numeric(12, 2) not null default 0 check (deposit_amount >= 0),
  deposit_paid boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create table public.rental_items (
  id uuid primary key default gen_random_uuid(),
  rental_id uuid not null references public.rentals(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  asset_id uuid references public.assets(id) on delete restrict,
  quantity integer not null default 1 check (quantity > 0),
  daily_rate_snapshot numeric(12, 2) not null check (daily_rate_snapshot >= 0),
  damage_notes text,
  returned_at timestamptz,
  created_at timestamptz not null default now(),
  check ((asset_id is null) or quantity = 1)
);

create table public.inventory_events (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete restrict,
  asset_id uuid references public.assets(id) on delete restrict,
  rental_id uuid references public.rentals(id) on delete set null,
  event_type text not null check (event_type in (
    'stock_adjusted', 'reserved', 'checked_out', 'returned', 'maintenance_started', 'maintenance_completed'
  )),
  quantity integer not null default 1 check (quantity > 0),
  occurred_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  notes text,
  check (product_id is not null or asset_id is not null)
);

-- Reserved for a future kit workflow. V1 treats every product independently.
create table public.kits (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null unique references public.products(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.kit_components (
  kit_id uuid not null references public.kits(id) on delete cascade,
  component_product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  primary key (kit_id, component_product_id)
);

create index products_category_id_idx on public.products(category_id);
create index products_manufacturer_id_idx on public.products(manufacturer_id);
create index product_identifiers_product_id_idx on public.product_identifiers(product_id);
create index assets_product_id_idx on public.assets(product_id);
create index rentals_client_id_idx on public.rentals(client_id);
create index rentals_status_idx on public.rentals(status);
create index rental_items_rental_id_idx on public.rental_items(rental_id);
create index rental_items_product_id_idx on public.rental_items(product_id);
create index rental_items_asset_id_idx on public.rental_items(asset_id);
create index inventory_events_product_id_idx on public.inventory_events(product_id);
create index inventory_events_asset_id_idx on public.inventory_events(asset_id);
create index inventory_events_rental_id_idx on public.inventory_events(rental_id);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

create trigger assets_set_updated_at
before update on public.assets
for each row execute function public.set_updated_at();

create trigger stock_balances_set_updated_at
before update on public.stock_balances
for each row execute function public.set_updated_at();

create trigger clients_set_updated_at
before update on public.clients
for each row execute function public.set_updated_at();

create trigger rentals_set_updated_at
before update on public.rentals
for each row execute function public.set_updated_at();

alter table public.categories enable row level security;
alter table public.manufacturers enable row level security;
alter table public.products enable row level security;
alter table public.product_identifiers enable row level security;
alter table public.assets enable row level security;
alter table public.stock_balances enable row level security;
alter table public.clients enable row level security;
alter table public.rentals enable row level security;
alter table public.rental_items enable row level security;
alter table public.inventory_events enable row level security;
alter table public.kits enable row level security;
alter table public.kit_components enable row level security;
