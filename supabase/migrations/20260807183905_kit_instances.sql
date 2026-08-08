-- Migration: Option C full physical kit tracking
-- Adds kit_instances (physical KIT-ID per kit) and kit_instance_components (KIT-ID → AST-ID)
-- This extends the existing kits / kit_components (product-level definitions) with
-- instance-level physical tracking.

-- Physical kit instances (one row per physical kit in the warehouse)
create table public.kit_instances (
  id          uuid primary key default gen_random_uuid(),
  kit_id      text not null unique,   -- e.g. KIT-ARRI-ORB-0001
  product_id  uuid not null references public.products(id) on delete restrict,
  kit_name    text not null,
  status      text not null default 'available'
    check (status in ('available', 'reserved', 'rented', 'maintenance', 'retired')),
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Links a physical kit instance to its physical child assets
create table public.kit_instance_components (
  id               uuid primary key default gen_random_uuid(),
  kit_instance_id  uuid not null references public.kit_instances(id) on delete cascade,
  asset_id         uuid not null references public.assets(id) on delete restrict,
  unique (kit_instance_id, asset_id)
);

-- Indexes
create index kit_instances_product_id_idx      on public.kit_instances(product_id);
create index kit_instances_status_idx          on public.kit_instances(status);
create index kit_instance_components_kit_idx   on public.kit_instance_components(kit_instance_id);
create index kit_instance_components_asset_idx on public.kit_instance_components(asset_id);

-- updated_at trigger
create trigger kit_instances_set_updated_at
before update on public.kit_instances
for each row execute function public.set_updated_at();

-- RLS
alter table public.kit_instances           enable row level security;
alter table public.kit_instance_components enable row level security;
