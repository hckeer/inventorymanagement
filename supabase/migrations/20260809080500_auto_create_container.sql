create or replace function public.link_assets_to_parent(p_parent_barcode text, p_child_barcodes text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_id uuid;
  v_container_product_id uuid;
begin
  -- Find the parent asset
  select id into v_parent_id
  from public.assets
  where asset_id = p_parent_barcode or manufacturer_serial = p_parent_barcode or internal_qr = p_parent_barcode;

  -- Auto-create parent asset if not found
  if not found then
    -- Find or create a generic 'Container' product
    select id into v_container_product_id
    from public.products
    where name = 'Generic Container'
    limit 1;

    if not found then
      insert into public.products (name, tracking_mode, daily_rate, notes)
      values ('Generic Container', 'serialized', 0, 'Auto-generated container product')
      returning id into v_container_product_id;
    end if;

    -- Create the new parent asset
    insert into public.assets (product_id, asset_id, status, notes)
    values (v_container_product_id, p_parent_barcode, 'available', 'Auto-created container')
    returning id into v_parent_id;
  end if;

  -- Update children
  update public.assets
  set parent_id = v_parent_id, updated_at = now()
  where asset_id = any(p_child_barcodes)
     or manufacturer_serial = any(p_child_barcodes)
     or internal_qr = any(p_child_barcodes);

end;
$$;
