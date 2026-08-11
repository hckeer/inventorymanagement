create function public.create_and_checkout_rental(p_client_id uuid, p_created_by uuid, p_start_date date, p_end_date date, p_deposit_amount numeric, p_deposit_paid boolean, p_notes text, p_items jsonb, p_parent_asset_ids uuid[], p_request_id uuid, p_override_asset_ids uuid[] default '{}'::uuid[], p_override_reason text default null)
returns public.rentals language plpgsql set search_path = '' as $$
declare v_rental public.rentals; v_rental_item_ids uuid[]; v_existing public.inventory_operations;
begin
  select * into v_existing
  from public.inventory_operations
  where request_id = p_request_id;

  if found then
    if v_existing.operation_type <> 'checkout' or v_existing.created_by <> p_created_by then
      raise exception 'Request ID belongs to another inventory operation';
    end if;
    select * into v_rental from public.rentals where id = v_existing.rental_id;
    return v_rental;
  end if;

  v_rental := public.create_rental(p_client_id, p_created_by, p_start_date, p_end_date, p_deposit_amount, p_deposit_paid, p_notes, p_items, p_override_asset_ids, p_override_reason);
  select array_agg(id order by id) into v_rental_item_ids from public.rental_items where rental_id = v_rental.id;
  return public.confirm_checkout(v_rental.id, p_created_by, coalesce(v_rental_item_ids, '{}'::uuid[]), p_parent_asset_ids, p_request_id);
end;
$$;

revoke execute on function public.create_and_checkout_rental(uuid, uuid, date, date, numeric, boolean, text, jsonb, uuid[], uuid, uuid[], text) from public, anon, authenticated;
grant execute on function public.create_and_checkout_rental(uuid, uuid, date, date, numeric, boolean, text, jsonb, uuid[], uuid, uuid[], text) to service_role;
