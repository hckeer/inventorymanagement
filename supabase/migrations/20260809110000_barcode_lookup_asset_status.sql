-- Barcode scans must make an availability decision for the specific physical
-- asset, rather than the aggregate product. Include status for the scanned
-- asset and every expanded container component.
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
  select a.*, p.name as product_name, p.tracking_mode
  into v_asset
  from public.assets a
  join public.products p on a.product_id = p.id
  where a.asset_id = p_identifier
     or a.manufacturer_serial = p_identifier
     or a.internal_qr = p_identifier
  limit 1;

  if found then
    with recursive descendants as (
      select id, product_id, asset_id, status
      from public.assets
      where parent_id = v_asset.id

      union

      select a.id, a.product_id, a.asset_id, a.status
      from public.assets a
      join descendants d on a.parent_id = d.id
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'asset_id', d.id,
      'product_id', d.product_id,
      'barcode', d.asset_id,
      'status', d.status
    )), '[]'::jsonb)
    into v_children
    from descendants d;

    return jsonb_build_object(
      'result_type', 'asset',
      'asset_id', v_asset.id,
      'product_id', v_asset.product_id,
      'product_name', v_asset.product_name,
      'tracking_mode', v_asset.tracking_mode,
      'asset_status', v_asset.status,
      'children', v_children
    );
  end if;

  select p.id, p.name, p.tracking_mode
  into v_product
  from public.product_identifiers pi
  join public.products p on pi.product_id = p.id
  where pi.identifier = p_identifier
  limit 1;

  if found then
    return jsonb_build_object(
      'result_type', 'product',
      'product_id', v_product.id,
      'product_name', v_product.name,
      'tracking_mode', v_product.tracking_mode
    );
  end if;

  return jsonb_build_object('result_type', 'unknown', 'identifier', p_identifier);
end;
$$;
