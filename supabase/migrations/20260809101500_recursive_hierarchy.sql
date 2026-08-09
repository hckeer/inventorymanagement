create or replace function public.lookup_barcode(p_identifier text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_asset record;
  v_product record;
  v_children jsonb;
begin
  -- 1. Try to find an asset matching the identifier
  select a.*, p.name as product_name, p.tracking_mode
  into v_asset
  from public.assets a
  join public.products p on a.product_id = p.id
  where a.asset_id = p_identifier 
     or a.manufacturer_serial = p_identifier 
     or a.internal_qr = p_identifier
  limit 1;

  if found then
    -- Find all recursive descendants of this asset
    with recursive descendants as (
      select id, product_id, asset_id
      from public.assets
      where parent_id = v_asset.id
      
      union all
      
      select a.id, a.product_id, a.asset_id
      from public.assets a
      join descendants d on a.parent_id = d.id
    )
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'asset_id', d.asset_id,
        'product_id', d.product_id
      )
    ), '[]'::jsonb) into v_children
    from descendants d;

    return jsonb_build_object(
      'result_type', 'asset',
      'asset_id', v_asset.asset_id,
      'product_id', v_asset.product_id,
      'product_name', v_asset.product_name,
      'tracking_mode', v_asset.tracking_mode,
      'children', v_children
    );
  end if;

  -- 2. If no asset found, try to find a product matching the identifier
  select * into v_product
  from public.products
  where sku = p_identifier or upc = p_identifier
  limit 1;

  if found then
    return jsonb_build_object(
      'result_type', 'product',
      'product_id', v_product.id,
      'product_name', v_product.name,
      'tracking_mode', v_product.tracking_mode
    );
  end if;

  -- 3. Unknown barcode
  return jsonb_build_object(
    'result_type', 'unknown',
    'identifier', p_identifier
  );
end;
$$;

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
    select id into v_product_id from public.products where name = v_parent_name limit 1;
    if not found then
      insert into public.products (name, tracking_mode, daily_rate, notes)
      values (v_parent_name, 'serialized', 0, 'Auto-generated container product')
      returning id into v_product_id;
    end if;

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
      select id into v_child_id
      from public.assets
      where asset_id = v_child_barcode or manufacturer_serial = v_child_barcode or internal_qr = v_child_barcode;

      if not found then
        select id into v_product_id from public.products where name = v_child_name limit 1;
        if not found then
          insert into public.products (name, tracking_mode, daily_rate, notes)
          values (v_child_name, 'serialized', 0, 'Auto-generated component product')
          returning id into v_product_id;
        end if;

        insert into public.assets (product_id, asset_id, status, notes, parent_id)
        values (v_product_id, v_child_barcode, 'available', 'Auto-created component', v_parent_id)
        returning id into v_child_id;
      else
        -- Cycle prevention
        if v_child_id = v_parent_id then
          raise exception 'An asset cannot contain itself';
        end if;

        if exists (
          with recursive ancestors as (
            select id, parent_id
            from public.assets
            where id = v_parent_id
            
            union all
            
            select a.id, a.parent_id
            from public.assets a
            join ancestors x on a.id = x.parent_id
          )
          select 1 from ancestors where id = v_child_id
        ) then
          raise exception 'Link would create an asset hierarchy cycle';
        end if;

        -- Link existing child asset
        update public.assets
        set parent_id = v_parent_id, updated_at = now()
        where id = v_child_id;
      end if;
    end;
  end loop;
end;
$$;
