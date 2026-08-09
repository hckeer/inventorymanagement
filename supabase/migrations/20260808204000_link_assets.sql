create or replace function public.link_assets_to_parent(p_parent_barcode text, p_child_barcodes text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_id uuid;
begin
  -- Find the parent asset
  select id into v_parent_id
  from public.assets
  where asset_id = p_parent_barcode or manufacturer_serial = p_parent_barcode or internal_qr = p_parent_barcode;

  if not found then
    raise exception 'Parent barcode % not found', p_parent_barcode;
  end if;

  -- Update children
  update public.assets
  set parent_id = v_parent_id, updated_at = now()
  where asset_id = any(p_child_barcodes)
     or manufacturer_serial = any(p_child_barcodes)
     or internal_qr = any(p_child_barcodes);

end;
$$;
