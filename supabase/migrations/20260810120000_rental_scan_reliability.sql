-- Checkout and return are committed from an explicit scan manifest.  The
-- manifest is also the idempotency boundary for a temporary network failure.

alter table public.rental_items
  add column if not exists returned_quantity integer not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'rental_items_returned_quantity_check'
      and conrelid = 'public.rental_items'::regclass
  ) then
    alter table public.rental_items
      add constraint rental_items_returned_quantity_check
      check (returned_quantity >= 0 and returned_quantity <= quantity);
  end if;
end $$;

create table if not exists public.rental_parent_snapshots (
  rental_id uuid not null references public.rentals(id) on delete cascade,
  parent_asset_id uuid not null references public.assets(id) on delete restrict,
  child_asset_id uuid not null references public.assets(id) on delete restrict,
  primary key (rental_id, parent_asset_id, child_asset_id),
  check (parent_asset_id <> child_asset_id)
);

create index if not exists rental_parent_snapshots_parent_idx
  on public.rental_parent_snapshots(rental_id, parent_asset_id);

create table if not exists public.inventory_operations (
  request_id uuid primary key,
  rental_id uuid not null references public.rentals(id) on delete restrict,
  operation_type text not null check (operation_type in ('checkout', 'return')),
  created_by uuid not null references auth.users(id) on delete restrict,
  verified_rental_item_ids uuid[] not null,
  returned_quantities jsonb not null default '[]'::jsonb,
  result_status text not null check (result_status in ('active', 'returned')),
  created_at timestamptz not null default now()
);

create index if not exists inventory_operations_rental_idx
  on public.inventory_operations(rental_id, created_at desc);

alter table public.rental_parent_snapshots enable row level security;
alter table public.inventory_operations enable row level security;

drop function if exists public.create_rental(uuid, uuid, date, date, numeric, boolean, text, jsonb);

create function public.create_rental(
  p_client_id uuid,
  p_created_by uuid,
  p_start_date date,
  p_end_date date,
  p_deposit_amount numeric,
  p_deposit_paid boolean,
  p_notes text,
  p_items jsonb,
  p_override_asset_ids uuid[] default '{}'::uuid[],
  p_override_reason text default null
)
returns public.rentals
language plpgsql
set search_path = ''
as $$
declare
  v_rental public.rentals;
  v_item record;
  v_asset public.assets;
  v_product public.products;
  v_available integer;
begin
  if p_end_date < p_start_date or jsonb_array_length(p_items) = 0 then
    raise exception 'Rental requires dates and at least one item';
  end if;
  if cardinality(p_override_asset_ids) > 0 and nullif(btrim(coalesce(p_override_reason, '')), '') is null then
    raise exception 'An override reason is required';
  end if;

  insert into public.rentals (client_id, created_by, start_date, end_date, deposit_amount, deposit_paid, notes)
  values (p_client_id, p_created_by, p_start_date, p_end_date, p_deposit_amount, p_deposit_paid, nullif(btrim(p_notes), ''))
  returning * into v_rental;

  for v_item in select * from jsonb_to_recordset(p_items) as x(product_id uuid, asset_id uuid, quantity integer) loop
    select * into v_product from public.products where id = v_item.product_id;
    if not found then raise exception 'Product not found'; end if;
    if v_item.asset_id is not null then
      select * into v_asset from public.assets where id = v_item.asset_id for update;
      if not found or v_asset.product_id <> v_item.product_id then raise exception 'Asset is not available'; end if;
      if v_asset.status <> 'available' then
        if v_asset.id = any(p_override_asset_ids) and v_asset.status in ('maintenance', 'retired') then
          insert into public.inventory_events (product_id, asset_id, rental_id, event_type, created_by, notes)
          values (v_item.product_id, v_asset.id, v_rental.id, 'stock_adjusted', p_created_by,
            'Physical availability override: ' || btrim(p_override_reason));
        else
          raise exception 'Asset is not available';
        end if;
      end if;
      update public.assets set status = 'reserved' where id = v_asset.id;
      insert into public.rental_items (rental_id, product_id, asset_id, quantity, daily_rate_snapshot)
      values (v_rental.id, v_item.product_id, v_item.asset_id, 1, v_product.daily_rate);
      insert into public.inventory_events (product_id, asset_id, rental_id, event_type, created_by)
      values (v_item.product_id, v_item.asset_id, v_rental.id, 'reserved', p_created_by);
    else
      if v_product.tracking_mode <> 'quantity' or coalesce(v_item.quantity, 0) < 1 then raise exception 'Quantity item is invalid'; end if;
      select on_hand_quantity - reserved_quantity - rented_quantity into v_available
      from public.stock_balances where product_id = v_item.product_id for update;
      if coalesce(v_available, 0) < v_item.quantity then raise exception 'Insufficient quantity'; end if;
      update public.stock_balances set reserved_quantity = reserved_quantity + v_item.quantity where product_id = v_item.product_id;
      insert into public.rental_items (rental_id, product_id, quantity, daily_rate_snapshot)
      values (v_rental.id, v_item.product_id, v_item.quantity, v_product.daily_rate);
      insert into public.inventory_events (product_id, rental_id, event_type, quantity, created_by)
      values (v_item.product_id, v_rental.id, 'reserved', v_item.quantity, p_created_by);
    end if;
  end loop;
  return v_rental;
end;
$$;

create or replace function public.confirm_checkout(
  p_rental_id uuid,
  p_created_by uuid,
  p_verified_rental_item_ids uuid[],
  p_parent_asset_ids uuid[],
  p_request_id uuid
)
returns public.rentals
language plpgsql
set search_path = ''
as $$
declare
  v_rental public.rentals;
  v_item public.rental_items;
  v_expected_ids uuid[];
  v_existing public.inventory_operations;
  v_parent_id uuid;
begin
  select * into v_existing
  from public.inventory_operations
  where request_id = p_request_id;

  if found then
    if v_existing.rental_id <> p_rental_id
       or v_existing.operation_type <> 'checkout'
       or v_existing.created_by <> p_created_by then
      raise exception 'Request ID belongs to another inventory operation';
    end if;
    select * into v_rental from public.rentals where id = p_rental_id;
    return v_rental;
  end if;

  select * into v_rental
  from public.rentals
  where id = p_rental_id
  for update;

  if not found or v_rental.status <> 'reserved' then
    raise exception 'Rental is not reserved';
  end if;

  select array_agg(id order by id) into v_expected_ids
  from public.rental_items
  where rental_id = p_rental_id;

  if coalesce(v_expected_ids, '{}'::uuid[]) <> coalesce(
    array(select distinct value::uuid from unnest(p_verified_rental_item_ids) value order by 1),
    '{}'::uuid[]
  ) or cardinality(p_verified_rental_item_ids) <> cardinality(v_expected_ids) then
    raise exception 'Scanned items do not exactly match the rental';
  end if;

  for v_parent_id in select distinct value from unnest(p_parent_asset_ids) value loop
    insert into public.rental_parent_snapshots (rental_id, parent_asset_id, child_asset_id)
    with recursive descendants as (
      select id from public.assets where parent_id = v_parent_id
      union all
      select asset.id from public.assets asset join descendants d on asset.parent_id = d.id
    )
    select p_rental_id, v_parent_id, d.id
    from descendants d
    join public.rental_items ri on ri.asset_id = d.id
    where ri.rental_id = p_rental_id
    on conflict do nothing;
  end loop;

  for v_item in select * from public.rental_items where rental_id = p_rental_id order by id loop
    if v_item.asset_id is not null then
      update public.assets set status = 'rented'
      where id = v_item.asset_id and status = 'reserved';
      if not found then raise exception 'Reserved asset is no longer available'; end if;
    else
      update public.stock_balances
      set reserved_quantity = reserved_quantity - v_item.quantity,
          rented_quantity = rented_quantity + v_item.quantity
      where product_id = v_item.product_id and reserved_quantity >= v_item.quantity;
      if not found then raise exception 'Reserved quantity is no longer available'; end if;
    end if;
    insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by)
    values (v_item.product_id, v_item.asset_id, p_rental_id, 'checked_out', v_item.quantity, p_created_by);
  end loop;

  update public.rentals set status = 'active' where id = p_rental_id returning * into v_rental;
  insert into public.inventory_operations (request_id, rental_id, operation_type, created_by, verified_rental_item_ids, result_status)
  values (p_request_id, p_rental_id, 'checkout', p_created_by, p_verified_rental_item_ids, 'active');
  return v_rental;
end;
$$;

create or replace function public.confirm_return(
  p_rental_id uuid,
  p_created_by uuid,
  p_verified_rental_item_ids uuid[],
  p_returned_quantities jsonb,
  p_request_id uuid
)
returns public.rentals
language plpgsql
set search_path = ''
as $$
declare
  v_rental public.rentals;
  v_item public.rental_items;
  v_existing public.inventory_operations;
  v_returned integer;
  v_quantity_ids uuid[];
begin
  select * into v_existing from public.inventory_operations where request_id = p_request_id;
  if found then
    if v_existing.rental_id <> p_rental_id or v_existing.operation_type <> 'return' or v_existing.created_by <> p_created_by then
      raise exception 'Request ID belongs to another inventory operation';
    end if;
    select * into v_rental from public.rentals where id = p_rental_id;
    return v_rental;
  end if;

  select * into v_rental from public.rentals where id = p_rental_id for update;
  if not found or v_rental.status <> 'active' then raise exception 'Rental is not active'; end if;

  if exists (
    select 1 from public.rental_items ri
    where ri.rental_id = p_rental_id and ri.asset_id is not null
      and not ri.id = any(p_verified_rental_item_ids)
  ) then
    raise exception 'Every serialized asset must be scanned before return';
  end if;

  select array_agg(id order by id) into v_quantity_ids
  from public.rental_items where rental_id = p_rental_id and asset_id is null;

  if coalesce(v_quantity_ids, '{}'::uuid[]) <> coalesce(
    array(select (value->>'rental_item_id')::uuid from jsonb_array_elements(p_returned_quantities) value order by 1),
    '{}'::uuid[]
  ) then
    raise exception 'Return quantities do not exactly match the rental quantity lines';
  end if;

  for v_item in select * from public.rental_items where rental_id = p_rental_id order by id loop
    if v_item.asset_id is not null then
      update public.assets set status = 'available'
      where id = v_item.asset_id and status = 'rented';
      if not found then raise exception 'Rented asset is no longer returnable'; end if;
      update public.rental_items set returned_at = now(), returned_quantity = 1 where id = v_item.id;
      insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by)
      values (v_item.product_id, v_item.asset_id, p_rental_id, 'returned', 1, p_created_by);
    else
      select (value->>'returned_quantity')::integer into v_returned
      from jsonb_array_elements(p_returned_quantities) value
      where (value->>'rental_item_id')::uuid = v_item.id;
      if v_returned is null or v_returned < 0 or v_returned > v_item.quantity then
        raise exception 'Invalid returned quantity';
      end if;
      update public.stock_balances set rented_quantity = rented_quantity - v_returned
      where product_id = v_item.product_id and rented_quantity >= v_returned;
      if not found then raise exception 'Rented quantity is no longer returnable'; end if;
      update public.rental_items set returned_at = now(), returned_quantity = v_returned where id = v_item.id;
      insert into public.inventory_events (product_id, rental_id, event_type, quantity, created_by)
      values (v_item.product_id, p_rental_id, 'returned', v_returned, p_created_by);
      if v_returned < v_item.quantity then
        insert into public.inventory_events (product_id, rental_id, event_type, quantity, created_by, notes)
        values (v_item.product_id, p_rental_id, 'stock_adjusted', v_item.quantity - v_returned, p_created_by, 'Missing on return');
      end if;
    end if;
  end loop;

  update public.rentals set status = 'returned' where id = p_rental_id returning * into v_rental;
  insert into public.inventory_operations (request_id, rental_id, operation_type, created_by, verified_rental_item_ids, returned_quantities, result_status)
  values (p_request_id, p_rental_id, 'return', p_created_by, p_verified_rental_item_ids, p_returned_quantities, 'returned');
  return v_rental;
end;
$$;

revoke execute on function public.confirm_checkout(uuid, uuid, uuid[], uuid[], uuid) from public, anon, authenticated;
revoke execute on function public.confirm_return(uuid, uuid, uuid[], jsonb, uuid) from public, anon, authenticated;
grant execute on function public.confirm_checkout(uuid, uuid, uuid[], uuid[], uuid) to service_role;
grant execute on function public.confirm_return(uuid, uuid, uuid[], jsonb, uuid) to service_role;
