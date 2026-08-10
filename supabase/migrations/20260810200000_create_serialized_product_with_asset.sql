-- A new serialized product and its scanned physical barcode must be created in
-- the same transaction. A product identifier is deliberately not used here:
-- it represents a model/quantity barcode, not a specific physical asset.
create function public.create_product_with_asset(
  p_name text,
  p_sku text,
  p_category_id uuid,
  p_manufacturer_id uuid,
  p_tracking_mode text,
  p_daily_rate numeric,
  p_notes text,
  p_identifiers jsonb default '[]'::jsonb,
  p_initial_quantity integer default 0,
  p_asset_barcode text default null
)
returns public.products
language plpgsql
set search_path = ''
as $$
declare
  v_product public.products;
  v_asset_barcode text := nullif(btrim(p_asset_barcode), '');
begin
  if v_asset_barcode is not null and p_tracking_mode <> 'serialized' then
    raise exception 'A physical asset barcode requires serialized tracking';
  end if;

  select * into v_product from public.create_product(
    p_name,
    p_sku,
    p_category_id,
    p_manufacturer_id,
    p_tracking_mode,
    p_daily_rate,
    p_notes,
    p_identifiers,
    p_initial_quantity
  );

  if v_asset_barcode is not null then
    insert into public.assets (product_id, asset_id, status)
    values (v_product.id, v_asset_barcode, 'available');
  end if;

  return v_product;
end;
$$;

revoke execute on function public.create_product_with_asset(text, text, uuid, uuid, text, numeric, text, jsonb, integer, text) from public, anon;
