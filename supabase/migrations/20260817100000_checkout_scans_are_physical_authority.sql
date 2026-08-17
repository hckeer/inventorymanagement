-- A known physical barcode is checkout authority.  Asset status, available
-- counts, and previous custody records are advisory and must not block staff.

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
  if not found or v_rental.status <> 'reserved' then
    raise exception 'Rental is not awaiting checkout';
  end if;

  select * into v_asset
  from public.assets
  where asset_id = nullif(btrim(p_barcode), '')
  for update;
  if not found then raise exception 'Unknown physical barcode'; end if;
  v_previous_status := v_asset.status;

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
    where rental_item_id = v_previous_assignment.rental_item_id
      and asset_id = v_asset.id;
    insert into public.inventory_events
      (product_id, asset_id, rental_id, event_type, quantity, created_by, notes)
    values
      (v_asset.product_id, v_asset.id, v_previous_rental_id, 'returned', 1,
       p_created_by, 'Closed by a later physical barcode checkout; scanner is authoritative');
  end if;

  select ri.* into v_line
  from public.rental_items ri
  join public.products p on p.id = ri.product_id
  where ri.rental_id = p_rental_id
    and ri.product_id = v_asset.product_id
    and p.tracking_mode = 'serialized'
    and (
      select count(*)
      from public.rental_asset_assignments raa
      where raa.rental_item_id = ri.id
        and raa.checkout_status in ('scanned', 'checked_out')
    ) < ri.quantity
  order by ri.created_at, ri.id
  limit 1
  for update;

  if not found then
    select * into v_product from public.products where id = v_asset.product_id;
    insert into public.rental_items
      (rental_id, product_id, quantity, daily_rate_snapshot)
    values (p_rental_id, v_asset.product_id, 1, v_product.daily_rate)
    returning * into v_line;
  end if;

  insert into public.rental_asset_assignments (rental_item_id, asset_id)
  values (v_line.id, v_asset.id)
  returning * into v_assignment;
  update public.assets set status = 'reserved' where id = v_asset.id;

  if v_previous_status <> 'available' then
    insert into public.inventory_events
      (product_id, asset_id, rental_id, event_type, quantity, created_by, notes)
    values
      (v_asset.product_id, v_asset.id, p_rental_id,
       'physical_presence_confirmed', 1, p_created_by,
       'Barcode scanned while database status was ' || v_previous_status ||
       '; scanner is authoritative');
  end if;
  insert into public.inventory_events
    (product_id, asset_id, rental_id, event_type, quantity, created_by, notes)
  values
    (v_asset.product_id, v_asset.id, p_rental_id, 'reserved', 1,
     p_created_by, 'Barcode scanned for checkout');
  return v_assignment;
end;
$$;

revoke execute on function public.scan_rental_checkout_asset(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.scan_rental_checkout_asset(uuid, uuid, text)
  to service_role;
