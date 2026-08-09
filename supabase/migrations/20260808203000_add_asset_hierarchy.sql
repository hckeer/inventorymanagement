alter table public.assets
add column parent_id uuid references public.assets(id) on delete set null;

create index assets_parent_id_idx on public.assets(parent_id);

-- Update lookup_barcode to include children if it's a parent asset
create or replace function public.lookup_barcode(p_identifier text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lookup record;
  v_children jsonb;
begin
  select a.id as asset_id, p.id as product_id, p.tracking_mode
  into v_lookup
  from public.assets a
  join public.products p on a.product_id = p.id
  where a.asset_id = p_identifier or a.internal_qr = p_identifier or a.manufacturer_serial = p_identifier;
  
  if found then
    -- Find children
    select jsonb_agg(
      jsonb_build_object(
        'asset_id', child.id,
        'product_id', child.product_id,
        'tracking_mode', p.tracking_mode,
        'barcode', child.asset_id
      )
    )
    into v_children
    from public.assets child
    join public.products p on child.product_id = p.id
    where child.parent_id = v_lookup.asset_id;

    return jsonb_build_object(
      'result_type', 'asset',
      'asset_id', v_lookup.asset_id,
      'product_id', v_lookup.product_id,
      'tracking_mode', v_lookup.tracking_mode,
      'children', coalesce(v_children, '[]'::jsonb)
    );
  end if;

  select p.id as product_id, p.tracking_mode
  into v_lookup
  from public.product_identifiers pi
  join public.products p on pi.product_id = p.id
  where pi.identifier = p_identifier;

  if found then
    return jsonb_build_object(
      'result_type', 'product',
      'product_id', v_lookup.product_id,
      'tracking_mode', v_lookup.tracking_mode
    );
  end if;

  return jsonb_build_object('result_type', 'unknown');
end;
$$;
