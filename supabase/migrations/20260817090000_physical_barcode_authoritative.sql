-- Physical barcode scans are the operational authority.  Booking capacity and
-- stale asset states are advisory only; every known sticker can be dispatched.

alter table public.rental_asset_assignments
  drop constraint if exists rental_asset_assignments_asset_id_key;

create unique index if not exists rental_asset_assignments_one_active_asset_idx
  on public.rental_asset_assignments (asset_id)
  where checkout_status in ('scanned', 'checked_out');

-- Clean up historic reservations which have no active scan assignment.  These
-- are stale status remnants, not equipment currently in dispatch custody.
update public.assets a
set status = 'available'
where a.status = 'reserved'
  and not exists (
    select 1
    from public.rental_asset_assignments raa
    where raa.asset_id = a.id
      and raa.checkout_status in ('scanned', 'checked_out')
  );

create or replace function public.create_rental(
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
  v_product public.products;
begin
  if p_end_date < p_start_date or coalesce(jsonb_array_length(p_items), 0) = 0 then
    raise exception 'Rental requires dates and at least one item';
  end if;
  if cardinality(p_override_asset_ids) > 0 then
    raise exception 'Physical asset overrides are only allowed at checkout';
  end if;

  insert into public.rentals (client_id, created_by, start_date, end_date, deposit_amount, deposit_paid, notes)
  values (p_client_id, p_created_by, p_start_date, p_end_date, p_deposit_amount, p_deposit_paid, nullif(btrim(p_notes), ''))
  returning * into v_rental;

  for v_item in select * from jsonb_to_recordset(p_items) as x(product_id uuid, asset_id uuid, quantity integer) loop
    if v_item.asset_id is not null then raise exception 'Do not assign serialized assets while booking'; end if;
    if coalesce(v_item.quantity, 0) < 1 then raise exception 'Requested quantity must be positive'; end if;

    select * into v_product from public.products where id = v_item.product_id and is_active for update;
    if not found then raise exception 'Product not found'; end if;

    -- Booking is an estimate. Do not reject it because stock records may be
    -- stale; exact physical barcode scans establish dispatch custody.
    if v_product.tracking_mode = 'quantity' then
      insert into public.stock_balances (product_id, on_hand_quantity, reserved_quantity, rented_quantity)
      values (v_product.id, 0, v_item.quantity, 0)
      on conflict (product_id) do update
      set reserved_quantity = public.stock_balances.reserved_quantity + excluded.reserved_quantity;
    end if;

    insert into public.rental_items (rental_id, product_id, quantity, daily_rate_snapshot)
    values (v_rental.id, v_product.id, v_item.quantity, v_product.daily_rate);
    insert into public.inventory_events (product_id, rental_id, event_type, quantity, created_by, notes)
    values (v_product.id, v_rental.id, 'reserved', v_item.quantity, p_created_by,
      'Booking estimate; physical barcode scan is dispatch authority');
  end loop;
  return v_rental;
end;
$$;

create or replace function public.scan_rental_checkout_asset(
  p_rental_id uuid, p_created_by uuid, p_barcode text
)
returns public.rental_asset_assignments
language plpgsql
set search_path = ''
as $$
declare
  v_rental public.rentals;
  v_asset public.assets;
  v_line public.rental_items;
  v_assignment public.rental_asset_assignments;
  v_previous_assignment public.rental_asset_assignments;
  v_previous_rental_id uuid;
  v_previous_status text;
  v_product public.products;
begin
  select * into v_rental from public.rentals where id = p_rental_id for update;
  if not found or v_rental.status <> 'reserved' then raise exception 'Rental is not awaiting checkout'; end if;
  select * into v_asset from public.assets where asset_id = nullif(btrim(p_barcode), '') for update;
  if not found then raise exception 'Unknown physical barcode'; end if;
  v_previous_status := v_asset.status;

  -- A repeat scan is idempotent. A scan into another rental is a physical
  -- takeover: close the stale/open prior custody record and retain its audit.
  select raa.* into v_previous_assignment
  from public.rental_asset_assignments raa
  join public.rental_items ri on ri.id = raa.rental_item_id
  where raa.asset_id = v_asset.id
    and raa.checkout_status in ('scanned', 'checked_out')
  for update;
  if found then
    select rental_id into v_previous_rental_id
    from public.rental_items
    where id = v_previous_assignment.rental_item_id;
    if v_previous_rental_id = p_rental_id then return v_previous_assignment; end if;
    update public.rental_asset_assignments
    set checkout_status = 'returned', returned_at = now()
    where rental_item_id = v_previous_assignment.rental_item_id and asset_id = v_asset.id;
    insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by, notes)
    values (v_asset.product_id, v_asset.id, v_previous_rental_id, 'returned', 1, p_created_by,
      'Closed by a later physical barcode checkout; scanner is authoritative');
  end if;

  select ri.* into v_line
  from public.rental_items ri
  join public.products p on p.id = ri.product_id
  where ri.rental_id = p_rental_id and ri.product_id = v_asset.product_id
    and p.tracking_mode = 'serialized'
    and (select count(*) from public.rental_asset_assignments raa where raa.rental_item_id = ri.id and raa.checkout_status in ('scanned', 'checked_out')) < ri.quantity
  order by ri.created_at, ri.id
  limit 1
  for update;

  if not found then
    select * into v_product from public.products where id = v_asset.product_id;
    insert into public.rental_items (rental_id, product_id, quantity, daily_rate_snapshot)
    values (p_rental_id, v_asset.product_id, 1, v_product.daily_rate)
    returning * into v_line;
  end if;

  insert into public.rental_asset_assignments (rental_item_id, asset_id)
  values (v_line.id, v_asset.id)
  returning * into v_assignment;
  update public.assets set status = 'reserved' where id = v_asset.id;
  if v_previous_status <> 'available' then
    insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by, notes)
    values (v_asset.product_id, v_asset.id, p_rental_id, 'physical_presence_confirmed', 1, p_created_by,
      'Barcode scanned while database status was ' || v_previous_status || '; scanner is authoritative');
  end if;
  insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by, notes)
  values (v_asset.product_id, v_asset.id, p_rental_id, 'reserved', 1, p_created_by, 'Barcode scanned for checkout');
  return v_assignment;
end;
$$;

create or replace function public.complete_rental_checkout(
  p_rental_id uuid, p_created_by uuid, p_quantity_checkout jsonb, p_request_id uuid
)
returns public.rentals
language plpgsql
set search_path = ''
as $$
declare
  v_rental public.rentals;
  v_line public.rental_items;
  v_existing public.inventory_operations;
  v_quantity integer;
  v_scanned integer;
begin
  select * into v_existing from public.inventory_operations where request_id = p_request_id;
  if found then
    if v_existing.rental_id <> p_rental_id or v_existing.operation_type <> 'checkout' or v_existing.created_by <> p_created_by then raise exception 'Request ID belongs to another inventory operation'; end if;
    select * into v_rental from public.rentals where id = p_rental_id; return v_rental;
  end if;
  select * into v_rental from public.rentals where id = p_rental_id for update;
  if not found or v_rental.status <> 'reserved' then raise exception 'Rental is not awaiting checkout'; end if;

  for v_line in select ri.* from public.rental_items ri join public.products p on p.id = ri.product_id where ri.rental_id = p_rental_id order by ri.id loop
    if exists (select 1 from public.products p where p.id = v_line.product_id and p.tracking_mode = 'serialized') then
      select count(*) into v_scanned from public.rental_asset_assignments where rental_item_id = v_line.id and checkout_status = 'scanned';
      if v_scanned = 0 then
        delete from public.rental_items where id = v_line.id;
      elsif v_scanned <> v_line.quantity then
        update public.rental_items set quantity = v_scanned where id = v_line.id;
      end if;
    else
      select (value->>'quantity')::integer into v_quantity from jsonb_array_elements(p_quantity_checkout) value where (value->>'rental_item_id')::uuid = v_line.id;
      if v_quantity is null or v_quantity < 0 then raise exception 'Checkout quantity is required'; end if;
      update public.stock_balances
      set reserved_quantity = greatest(0, reserved_quantity - v_quantity),
          rented_quantity = rented_quantity + v_quantity
      where product_id = v_line.product_id;
      update public.rental_items set quantity = v_quantity where id = v_line.id;
    end if;
  end loop;

  update public.assets a set status = 'rented'
  from public.rental_asset_assignments raa
  where raa.asset_id = a.id and raa.checkout_status = 'scanned'
    and raa.rental_item_id in (select id from public.rental_items where rental_id = p_rental_id);
  update public.rental_asset_assignments set checkout_status = 'checked_out'
  where checkout_status = 'scanned'
    and rental_item_id in (select id from public.rental_items where rental_id = p_rental_id);
  insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by)
  select ri.product_id, raa.asset_id, p_rental_id, 'checked_out', 1, p_created_by
  from public.rental_asset_assignments raa join public.rental_items ri on ri.id = raa.rental_item_id
  where ri.rental_id = p_rental_id and raa.checkout_status = 'checked_out';
  update public.rentals set status = 'active' where id = p_rental_id returning * into v_rental;
  insert into public.inventory_operations (request_id, rental_id, operation_type, created_by, verified_rental_item_ids, returned_quantities, result_status)
  values (p_request_id, p_rental_id, 'checkout', p_created_by, '{}'::uuid[], p_quantity_checkout, 'active');
  return v_rental;
end;
$$;

revoke execute on function public.create_rental(uuid, uuid, date, date, numeric, boolean, text, jsonb, uuid[], text) from public, anon, authenticated;
revoke execute on function public.scan_rental_checkout_asset(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function public.complete_rental_checkout(uuid, uuid, jsonb, uuid) from public, anon, authenticated;
grant execute on function public.create_rental(uuid, uuid, date, date, numeric, boolean, text, jsonb, uuid[], text) to service_role;
grant execute on function public.scan_rental_checkout_asset(uuid, uuid, text) to service_role;
grant execute on function public.complete_rental_checkout(uuid, uuid, jsonb, uuid) to service_role;
