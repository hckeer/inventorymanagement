-- Serialized equipment is reserved by model at booking time.  A physical asset
-- is never selected until its printed barcode is scanned at checkout.

create table public.rental_asset_assignments (
  rental_item_id uuid not null references public.rental_items(id) on delete cascade,
  asset_id uuid not null references public.assets(id) on delete restrict,
  checkout_status text not null default 'scanned'
    check (checkout_status in ('scanned', 'checked_out', 'returned', 'damaged', 'lost')),
  scanned_at timestamptz not null default now(),
  returned_at timestamptz,
  primary key (rental_item_id, asset_id),
  unique (asset_id),
  check ((checkout_status in ('returned', 'damaged', 'lost')) = (returned_at is not null))
);

create index rental_asset_assignments_asset_status_idx
  on public.rental_asset_assignments(asset_id, checkout_status);

alter table public.rental_asset_assignments enable row level security;

-- Remove the incorrect booking-time allocator even if a previous migration
-- installed it.  The API must not expose a replacement for this function.
drop function if exists public.create_rental_with_auto_allocation(uuid, uuid, date, date, numeric, boolean, text, jsonb);

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
  v_available integer;
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
    if v_item.asset_id is not null then
      raise exception 'Do not assign serialized assets while booking';
    end if;
    if coalesce(v_item.quantity, 0) < 1 then
      raise exception 'Requested quantity must be positive';
    end if;

    -- Lock the product row so concurrent bookings for the same model cannot
    -- both consume the final reservable unit.
    select * into v_product from public.products
    where id = v_item.product_id and is_active
    for update;
    if not found then raise exception 'Product not found'; end if;

    if v_product.tracking_mode = 'serialized' then
      select
        count(*) filter (where a.status in ('available', 'reserved'))
        - coalesce((
          select sum(ri.quantity)
          from public.rental_items ri
          join public.rentals r on r.id = ri.rental_id
          join public.products p on p.id = ri.product_id
          where ri.product_id = v_product.id
            and ri.asset_id is null
            and p.tracking_mode = 'serialized'
            and r.status = 'reserved'
        ), 0)
        - coalesce((
          select count(*)
          from public.rental_items ri
          join public.rentals r on r.id = ri.rental_id
          where ri.product_id = v_product.id
            and ri.asset_id is not null
            and r.status = 'reserved'
        ), 0)
      into v_available
      from public.assets a
      where a.product_id = v_product.id;
      if coalesce(v_available, 0) < v_item.quantity then
        raise exception 'Insufficient available serialized equipment';
      end if;
    else
      select on_hand_quantity - reserved_quantity - rented_quantity into v_available
      from public.stock_balances where product_id = v_product.id for update;
      if coalesce(v_available, 0) < v_item.quantity then raise exception 'Insufficient quantity'; end if;
      update public.stock_balances
      set reserved_quantity = reserved_quantity + v_item.quantity
      where product_id = v_product.id;
    end if;

    insert into public.rental_items (rental_id, product_id, quantity, daily_rate_snapshot)
    values (v_rental.id, v_product.id, v_item.quantity, v_product.daily_rate);
    insert into public.inventory_events (product_id, rental_id, event_type, quantity, created_by)
    values (v_product.id, v_rental.id, 'reserved', v_item.quantity, p_created_by);
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
begin
  select * into v_rental from public.rentals where id = p_rental_id for update;
  if not found or v_rental.status <> 'reserved' then raise exception 'Rental is not awaiting checkout'; end if;
  select * into v_asset from public.assets where asset_id = nullif(btrim(p_barcode), '') for update;
  if not found then raise exception 'Unknown physical barcode'; end if;
  if v_asset.status <> 'available' then raise exception 'Asset is not available for checkout'; end if;

  select ri.* into v_line
  from public.rental_items ri join public.products p on p.id = ri.product_id
  where ri.rental_id = p_rental_id and ri.product_id = v_asset.product_id
    and ri.asset_id is null and p.tracking_mode = 'serialized'
    and (select count(*) from public.rental_asset_assignments raa where raa.rental_item_id = ri.id) < ri.quantity
  order by ri.created_at, ri.id
  limit 1
  for update;
  if not found then raise exception 'This asset model is not requested or is already fully scanned'; end if;

  insert into public.rental_asset_assignments (rental_item_id, asset_id)
  values (v_line.id, v_asset.id)
  returning * into v_assignment;
  update public.assets set status = 'reserved' where id = v_asset.id;
  insert into public.inventory_events (product_id, asset_id, rental_id, event_type, created_by, notes)
  values (v_asset.product_id, v_asset.id, p_rental_id, 'reserved', p_created_by, 'Barcode scanned for checkout');
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
      if (select count(*) from public.rental_asset_assignments where rental_item_id = v_line.id and checkout_status = 'scanned') <> v_line.quantity then
        raise exception 'Every requested serialized unit must be scanned before checkout';
      end if;
    else
      select (value->>'quantity')::integer into v_quantity from jsonb_array_elements(p_quantity_checkout) value where (value->>'rental_item_id')::uuid = v_line.id;
      if v_quantity is null or v_quantity <> v_line.quantity then raise exception 'Checkout quantities must exactly match every quantity line'; end if;
      update public.stock_balances set reserved_quantity = reserved_quantity - v_line.quantity, rented_quantity = rented_quantity + v_line.quantity where product_id = v_line.product_id and reserved_quantity >= v_line.quantity;
      if not found then raise exception 'Reserved quantity is no longer available'; end if;
    end if;
  end loop;
  if (select count(*) from jsonb_array_elements(p_quantity_checkout)) <> (select count(*) from public.rental_items ri join public.products p on p.id=ri.product_id where ri.rental_id=p_rental_id and p.tracking_mode='quantity') then raise exception 'Checkout quantities do not exactly match rental quantity lines'; end if;
  update public.assets a set status = 'rented' from public.rental_asset_assignments raa where raa.asset_id = a.id and raa.checkout_status = 'scanned' and raa.rental_item_id in (select id from public.rental_items where rental_id = p_rental_id);
  update public.rental_asset_assignments set checkout_status = 'checked_out' where checkout_status = 'scanned' and rental_item_id in (select id from public.rental_items where rental_id = p_rental_id);
  insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by)
  select ri.product_id, raa.asset_id, p_rental_id, 'checked_out', 1, p_created_by from public.rental_asset_assignments raa join public.rental_items ri on ri.id=raa.rental_item_id where raa.rental_item_id in (select id from public.rental_items where rental_id=p_rental_id);
  update public.rentals set status = 'active' where id = p_rental_id returning * into v_rental;
  insert into public.inventory_operations (request_id, rental_id, operation_type, created_by, verified_rental_item_ids, returned_quantities, result_status) values (p_request_id, p_rental_id, 'checkout', p_created_by, '{}'::uuid[], p_quantity_checkout, 'active');
  return v_rental;
end;
$$;

create or replace function public.scan_rental_return_asset(
  p_rental_id uuid, p_created_by uuid, p_barcode text, p_disposition text
)
returns public.rental_asset_assignments
language plpgsql
set search_path = ''
as $$
declare v_rental public.rentals; v_asset public.assets; v_assignment public.rental_asset_assignments;
begin
  if p_disposition not in ('returned', 'damaged', 'lost') then raise exception 'Invalid return disposition'; end if;
  select * into v_rental from public.rentals where id=p_rental_id for update;
  if not found or v_rental.status <> 'active' then raise exception 'Rental is not active'; end if;
  select * into v_asset from public.assets where asset_id=nullif(btrim(p_barcode), '') for update;
  if not found then raise exception 'Unknown physical barcode'; end if;
  select raa.* into v_assignment from public.rental_asset_assignments raa join public.rental_items ri on ri.id=raa.rental_item_id where ri.rental_id=p_rental_id and raa.asset_id=v_asset.id and raa.checkout_status='checked_out' for update;
  if not found then raise exception 'Scanned asset does not belong to this active rental'; end if;
  update public.rental_asset_assignments set checkout_status=p_disposition, returned_at=now() where rental_item_id=v_assignment.rental_item_id and asset_id=v_asset.id returning * into v_assignment;
  update public.assets set status=case p_disposition when 'returned' then 'available' when 'damaged' then 'maintenance' else 'retired' end where id=v_asset.id;
  insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by) values (v_asset.product_id, v_asset.id, p_rental_id, p_disposition, 1, p_created_by);
  return v_assignment;
end;
$$;

create or replace function public.complete_rental_return(
  p_rental_id uuid, p_created_by uuid, p_returned_quantities jsonb, p_request_id uuid
)
returns public.rentals
language plpgsql
set search_path = ''
as $$
declare v_rental public.rentals; v_line public.rental_items; v_returned integer; v_existing public.inventory_operations;
begin
  select * into v_existing from public.inventory_operations where request_id=p_request_id;
  if found then
    if v_existing.rental_id <> p_rental_id or v_existing.operation_type <> 'return' or v_existing.created_by <> p_created_by then raise exception 'Request ID belongs to another inventory operation'; end if;
    select * into v_rental from public.rentals where id=p_rental_id; return v_rental;
  end if;
  select * into v_rental from public.rentals where id=p_rental_id for update;
  if not found or v_rental.status <> 'active' then raise exception 'Rental is not active'; end if;
  for v_line in select ri.* from public.rental_items ri join public.products p on p.id=ri.product_id where ri.rental_id=p_rental_id and p.tracking_mode='quantity' loop
    select (value->>'returned_quantity')::integer into v_returned from jsonb_array_elements(p_returned_quantities) value where (value->>'rental_item_id')::uuid=v_line.id;
    if v_returned is null or v_returned < 0 or v_returned > v_line.quantity then raise exception 'Invalid returned quantity'; end if;
    update public.stock_balances set rented_quantity=rented_quantity-v_line.quantity, on_hand_quantity=on_hand_quantity-(v_line.quantity-v_returned) where product_id=v_line.product_id and rented_quantity >= v_line.quantity;
    if not found then raise exception 'Rented quantity is no longer returnable'; end if;
    update public.rental_items set returned_at=now(), returned_quantity=v_returned where id=v_line.id;
    if v_returned > 0 then insert into public.inventory_events(product_id,rental_id,event_type,quantity,created_by) values(v_line.product_id,p_rental_id,'returned',v_returned,p_created_by); end if;
    if v_returned < v_line.quantity then insert into public.inventory_events(product_id,rental_id,event_type,quantity,created_by,notes) values(v_line.product_id,p_rental_id,'missing',v_line.quantity-v_returned,p_created_by,'Missing on return'); end if;
  end loop;
  if (select count(*) from jsonb_array_elements(p_returned_quantities)) <> (select count(*) from public.rental_items ri join public.products p on p.id=ri.product_id where ri.rental_id=p_rental_id and p.tracking_mode='quantity') then raise exception 'Return quantities do not exactly match rental quantity lines'; end if;
  if not exists (select 1 from public.rental_asset_assignments raa join public.rental_items ri on ri.id=raa.rental_item_id where ri.rental_id=p_rental_id and raa.checkout_status='checked_out') then update public.rentals set status='returned' where id=p_rental_id returning * into v_rental; else insert into public.inventory_events(product_id,rental_id,event_type,quantity,created_by,notes) select ri.product_id,p_rental_id,'missing',1,p_created_by,'Unscanned at return; asset remains rented for review' from public.rental_asset_assignments raa join public.rental_items ri on ri.id=raa.rental_item_id where ri.rental_id=p_rental_id and raa.checkout_status='checked_out'; end if;
  insert into public.inventory_operations(request_id,rental_id,operation_type,created_by,verified_rental_item_ids,returned_quantities,result_status) values(p_request_id,p_rental_id,'return',p_created_by,'{}'::uuid[],p_returned_quantities,case when v_rental.status='returned' then 'returned' else 'active' end);
  return v_rental;
end;
$$;

revoke execute on function public.create_rental(uuid, uuid, date, date, numeric, boolean, text, jsonb, uuid[], text) from public, anon, authenticated;
revoke execute on function public.scan_rental_checkout_asset(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function public.complete_rental_checkout(uuid, uuid, jsonb, uuid) from public, anon, authenticated;
revoke execute on function public.scan_rental_return_asset(uuid, uuid, text, text) from public, anon, authenticated;
revoke execute on function public.complete_rental_return(uuid, uuid, jsonb, uuid) from public, anon, authenticated;
grant execute on function public.create_rental(uuid, uuid, date, date, numeric, boolean, text, jsonb, uuid[], text) to service_role;
grant execute on function public.scan_rental_checkout_asset(uuid, uuid, text) to service_role;
grant execute on function public.complete_rental_checkout(uuid, uuid, jsonb, uuid) to service_role;
grant execute on function public.scan_rental_return_asset(uuid, uuid, text, text) to service_role;
grant execute on function public.complete_rental_return(uuid, uuid, jsonb, uuid) to service_role;
