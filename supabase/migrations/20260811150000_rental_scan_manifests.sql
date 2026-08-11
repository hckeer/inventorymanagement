create table public.rental_scan_items (
  rental_id uuid not null references public.rentals(id) on delete cascade,
  barcode text not null check (btrim(barcode) <> ''),
  checked_in_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (rental_id, barcode)
);

create index rental_scan_items_open_idx on public.rental_scan_items(rental_id) where checked_in_at is null;
alter table public.rental_scan_items enable row level security;

create table public.rental_scan_operations (
  request_id uuid primary key,
  rental_id uuid not null references public.rentals(id) on delete restrict,
  operation_type text not null check (operation_type in ('checkout', 'return')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
alter table public.rental_scan_operations enable row level security;

create function public.create_manifest_checkout_rental(
  p_client_id uuid, p_created_by uuid, p_start_date date, p_end_date date,
  p_deposit_amount numeric, p_deposit_paid boolean, p_notes text,
  p_barcodes text[], p_request_id uuid
) returns public.rentals language plpgsql set search_path = '' as $$
declare v_rental public.rentals; v_existing public.rental_scan_operations;
begin
  select * into v_existing from public.rental_scan_operations where request_id = p_request_id;
  if found then
    if v_existing.operation_type <> 'checkout' or v_existing.created_by <> p_created_by then
      raise exception 'Request ID belongs to another scan operation';
    end if;
    select * into v_rental from public.rentals where id = v_existing.rental_id;
    return v_rental;
  end if;
  if p_end_date < p_start_date or cardinality(p_barcodes) = 0 or exists (select 1 from unnest(p_barcodes) barcode where nullif(btrim(barcode), '') is null) then
    raise exception 'Rental requires dates and at least one scanned barcode';
  end if;
  if cardinality(p_barcodes) <> cardinality(array(select distinct btrim(barcode) from unnest(p_barcodes) barcode)) then
    raise exception 'Each physical barcode can be scanned only once';
  end if;
  insert into public.rentals (client_id, created_by, start_date, end_date, status, deposit_amount, deposit_paid, notes)
  values (p_client_id, p_created_by, p_start_date, p_end_date, 'active', p_deposit_amount, p_deposit_paid, nullif(btrim(p_notes), ''))
  returning * into v_rental;
  insert into public.rental_scan_items (rental_id, barcode)
  select v_rental.id, btrim(barcode) from unnest(p_barcodes) barcode;
  insert into public.rental_scan_operations (request_id, rental_id, operation_type, created_by)
  values (p_request_id, v_rental.id, 'checkout', p_created_by);
  return v_rental;
end;
$$;

create function public.confirm_manifest_return(
  p_rental_id uuid, p_created_by uuid, p_barcodes text[], p_request_id uuid
) returns jsonb language plpgsql set search_path = '' as $$
declare v_rental public.rentals; v_existing public.rental_scan_operations; v_missing text[];
begin
  select * into v_existing from public.rental_scan_operations where request_id = p_request_id;
  if found then
    if v_existing.rental_id <> p_rental_id or v_existing.operation_type <> 'return' or v_existing.created_by <> p_created_by then
      raise exception 'Request ID belongs to another scan operation';
    end if;
    select * into v_rental from public.rentals where id = p_rental_id;
    select coalesce(array_agg(barcode order by barcode), '{}'::text[]) into v_missing from public.rental_scan_items where rental_id = p_rental_id and checked_in_at is null;
    return jsonb_build_object('rental', to_jsonb(v_rental), 'missing_barcodes', to_jsonb(v_missing));
  end if;
  select * into v_rental from public.rentals where id = p_rental_id for update;
  if not found or v_rental.status <> 'active' then raise exception 'Rental is not active'; end if;
  if exists (select 1 from unnest(p_barcodes) barcode where nullif(btrim(barcode), '') is null)
    or cardinality(p_barcodes) <> cardinality(array(select distinct btrim(barcode) from unnest(p_barcodes) barcode)) then
    raise exception 'Each returned barcode must be scanned once';
  end if;
  if exists (select 1 from unnest(p_barcodes) barcode where not exists (select 1 from public.rental_scan_items item where item.rental_id = p_rental_id and item.barcode = btrim(barcode))) then
    raise exception 'A scanned barcode is not in this rental';
  end if;
  update public.rental_scan_items set checked_in_at = now() where rental_id = p_rental_id and barcode = any(array(select btrim(barcode) from unnest(p_barcodes) barcode));
  select coalesce(array_agg(barcode order by barcode), '{}'::text[]) into v_missing from public.rental_scan_items where rental_id = p_rental_id and checked_in_at is null;
  update public.rentals set status = 'returned' where id = p_rental_id returning * into v_rental;
  insert into public.rental_scan_operations (request_id, rental_id, operation_type, created_by) values (p_request_id, p_rental_id, 'return', p_created_by);
  return jsonb_build_object('rental', to_jsonb(v_rental), 'missing_barcodes', to_jsonb(v_missing));
end;
$$;

revoke execute on function public.create_manifest_checkout_rental(uuid, uuid, date, date, numeric, boolean, text, text[], uuid) from public, anon, authenticated;
revoke execute on function public.confirm_manifest_return(uuid, uuid, text[], uuid) from public, anon, authenticated;
grant execute on function public.create_manifest_checkout_rental(uuid, uuid, date, date, numeric, boolean, text, text[], uuid) to service_role;
grant execute on function public.confirm_manifest_return(uuid, uuid, text[], uuid) to service_role;
