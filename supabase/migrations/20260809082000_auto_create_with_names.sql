create or replace function public.link_assets_to_parent(p_parent jsonb, p_children jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_id uuid;
  v_parent_barcode text;
  v_parent_name text;
  v_child record;
  v_child_id uuid;
  v_product_id uuid;
begin
  v_parent_barcode := p_parent->>'barcode';
  v_parent_name := coalesce(p_parent->>'name', 'Generic Container');

  -- Find the parent asset
  select id into v_parent_id
  from public.assets
  where asset_id = v_parent_barcode or manufacturer_serial = v_parent_barcode or internal_qr = v_parent_barcode;

  -- Auto-create parent asset if not found
  if not found then
    -- Find or create the product with that name
    select id into v_product_id
    from public.products
    where name = v_parent_name
    limit 1;

    if not found then
      insert into public.products (name, tracking_mode, daily_rate, notes)
      values (v_parent_name, 'serialized', 0, 'Auto-generated container product')
      returning id into v_product_id;
    end if;

    -- Create the new parent asset
    insert into public.assets (product_id, asset_id, status, notes)
    values (v_product_id, v_parent_barcode, 'available', 'Auto-created container')
    returning id into v_parent_id;
  end if;

  -- Process children
  for v_child in select * from jsonb_array_elements(p_children) loop
    declare
      v_child_barcode text := v_child.value->>'barcode';
      v_child_name text := coalesce(nullif(v_child.value->>'name', ''), 'Generic Component');
    begin
      -- Find child asset
      select id into v_child_id
      from public.assets
      where asset_id = v_child_barcode or manufacturer_serial = v_child_barcode or internal_qr = v_child_barcode;

      if not found then
        -- Find or create product
        select id into v_product_id
        from public.products
        where name = v_child_name
        limit 1;

        if not found then
          insert into public.products (name, tracking_mode, daily_rate, notes)
          values (v_child_name, 'serialized', 0, 'Auto-generated component product')
          returning id into v_product_id;
        end if;

        -- Create child asset
        insert into public.assets (product_id, asset_id, status, notes, parent_id)
        values (v_product_id, v_child_barcode, 'available', 'Auto-created component', v_parent_id)
        returning id into v_child_id;
      else
        -- Link existing child asset
        update public.assets
        set parent_id = v_parent_id, updated_at = now()
        where id = v_child_id;
      end if;
    end;
  end loop;

end;
$$;
