create function public.assert_identifier_available(
  p_identifier text,
  p_asset_id uuid default null,
  p_product_identifier_id uuid default null
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.product_identifiers
    where identifier = p_identifier
      and id is distinct from p_product_identifier_id
  ) or exists (
    select 1
    from public.assets
    where id is distinct from p_asset_id
      and p_identifier in (asset_id, manufacturer_serial, internal_qr)
  ) then
    raise exception 'Identifier % is already in use', p_identifier
      using errcode = 'unique_violation';
  end if;
end;
$$;

create function public.validate_product_identifier()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.identifier = btrim(new.identifier);
  if new.identifier = '' then
    raise exception 'Identifier is required';
  end if;
  perform public.assert_identifier_available(new.identifier, null, new.id);
  return new;
end;
$$;

create trigger product_identifiers_validate_identifier
before insert or update of identifier on public.product_identifiers
for each row execute function public.validate_product_identifier();

create function public.validate_asset()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_identifier text;
begin
  if not exists (
    select 1 from public.products
    where id = new.product_id and tracking_mode = 'serialized'
  ) then
    raise exception 'Assets require a serialized product';
  end if;

  new.asset_id = btrim(new.asset_id);
  if new.asset_id = '' then
    raise exception 'asset_id is required';
  end if;

  foreach v_identifier in array array[new.asset_id, new.manufacturer_serial, new.internal_qr]
  loop
    if v_identifier is not null then
      v_identifier = btrim(v_identifier);
      if v_identifier = '' then
        raise exception 'Asset identifiers cannot be blank';
      end if;
      perform public.assert_identifier_available(v_identifier, new.id, null);
    end if;
  end loop;
  new.manufacturer_serial = nullif(btrim(new.manufacturer_serial), '');
  new.internal_qr = nullif(btrim(new.internal_qr), '');
  return new;
end;
$$;

create trigger assets_validate_identifiers
before insert or update of product_id, asset_id, manufacturer_serial, internal_qr on public.assets
for each row execute function public.validate_asset();

create function public.create_product(
  p_name text,
  p_sku text,
  p_category_id uuid,
  p_manufacturer_id uuid,
  p_tracking_mode text,
  p_daily_rate numeric,
  p_notes text,
  p_identifiers jsonb default '[]'::jsonb,
  p_initial_quantity integer default 0
)
returns public.products
language plpgsql
set search_path = ''
as $$
declare
  v_product public.products;
  v_identifier record;
begin
  if p_tracking_mode not in ('serialized', 'quantity') then
    raise exception 'tracking_mode must be serialized or quantity';
  end if;
  if p_initial_quantity < 0 or (p_tracking_mode = 'serialized' and p_initial_quantity <> 0) then
    raise exception 'initial_quantity is only supported for quantity products';
  end if;

  insert into public.products (
    name, sku, category_id, manufacturer_id, tracking_mode, daily_rate, notes
  ) values (
    btrim(p_name), nullif(btrim(p_sku), ''), p_category_id, p_manufacturer_id,
    p_tracking_mode, p_daily_rate, nullif(btrim(p_notes), '')
  ) returning * into v_product;

  for v_identifier in
    select identifier, identifier_type
    from jsonb_to_recordset(p_identifiers) as value(identifier text, identifier_type text)
  loop
    insert into public.product_identifiers (product_id, identifier, identifier_type)
    values (v_product.id, v_identifier.identifier, v_identifier.identifier_type);
  end loop;

  insert into public.stock_balances (product_id, on_hand_quantity)
  values (v_product.id, p_initial_quantity);

  return v_product;
end;
$$;

create function public.lookup_barcode(p_identifier text)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  select jsonb_build_object(
    'result_type', 'serialized',
    'asset', to_jsonb(a),
    'product', to_jsonb(p)
  ) into v_result
  from public.assets a
  join public.products p on p.id = a.product_id
  where p_identifier in (a.asset_id, a.manufacturer_serial, a.internal_qr)
  limit 1;

  if v_result is not null then
    return v_result;
  end if;

  select jsonb_build_object(
    'result_type', 'quantity',
    'product', to_jsonb(p),
    'identifier', to_jsonb(pi)
  ) into v_result
  from public.product_identifiers pi
  join public.products p on p.id = pi.product_id
  where pi.identifier = p_identifier
  limit 1;

  return coalesce(v_result, jsonb_build_object('result_type', 'unknown'));
end;
$$;

revoke execute on function public.create_product(text, text, uuid, uuid, text, numeric, text, jsonb, integer) from public, anon;
revoke execute on function public.lookup_barcode(text) from public, anon;
