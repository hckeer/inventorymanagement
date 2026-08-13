-- Approved UAT checkout associations. These are optional suggestions only:
-- they do not create kits, parent-child asset links, or forced rental lines.
create table public.checkout_suggestions (
  id uuid primary key default gen_random_uuid(),
  association_id text not null unique,
  serialized_product_id uuid not null references public.products(id) on delete cascade,
  quantity_product_id uuid not null references public.products(id) on delete restrict,
  default_quantity integer not null check (default_quantity > 0),
  reason text,
  created_at timestamptz not null default now(),
  unique (serialized_product_id, quantity_product_id)
);

create index checkout_suggestions_serialized_product_idx
  on public.checkout_suggestions(serialized_product_id);

create function public.validate_checkout_suggestion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.products where id = new.serialized_product_id and tracking_mode = 'serialized'
  ) then
    raise exception 'Checkout suggestion source must be a serialized product';
  end if;
  if not exists (
    select 1 from public.products where id = new.quantity_product_id and tracking_mode = 'quantity'
  ) then
    raise exception 'Checkout suggestion target must be a quantity product';
  end if;
  return new;
end;
$$;

create trigger checkout_suggestions_validate
before insert or update of serialized_product_id, quantity_product_id on public.checkout_suggestions
for each row execute function public.validate_checkout_suggestion();

alter table public.checkout_suggestions enable row level security;
