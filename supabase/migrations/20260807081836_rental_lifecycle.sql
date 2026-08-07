create function public.create_rental(p_client_id uuid, p_created_by uuid, p_start_date date, p_end_date date, p_deposit_amount numeric, p_deposit_paid boolean, p_notes text, p_items jsonb)
returns public.rentals language plpgsql set search_path = '' as $$
declare v_rental public.rentals; v_item record; v_asset public.assets; v_product public.products; v_available integer;
begin
  if p_end_date < p_start_date or jsonb_array_length(p_items) = 0 then raise exception 'Rental requires dates and at least one item'; end if;
  insert into public.rentals (client_id, created_by, start_date, end_date, deposit_amount, deposit_paid, notes) values (p_client_id, p_created_by, p_start_date, p_end_date, p_deposit_amount, p_deposit_paid, nullif(btrim(p_notes), '')) returning * into v_rental;
  for v_item in select * from jsonb_to_recordset(p_items) as x(product_id uuid, asset_id uuid, quantity integer) loop
    select * into v_product from public.products where id = v_item.product_id;
    if not found then raise exception 'Product not found'; end if;
    if v_item.asset_id is not null then
      select * into v_asset from public.assets where id = v_item.asset_id for update;
      if not found or v_asset.product_id <> v_item.product_id or v_asset.status <> 'available' then raise exception 'Asset is not available'; end if;
      update public.assets set status = 'reserved' where id = v_asset.id;
      insert into public.rental_items (rental_id, product_id, asset_id, quantity, daily_rate_snapshot) values (v_rental.id, v_item.product_id, v_item.asset_id, 1, v_product.daily_rate);
      insert into public.inventory_events (product_id, asset_id, rental_id, event_type, created_by) values (v_item.product_id, v_item.asset_id, v_rental.id, 'reserved', p_created_by);
    else
      if v_product.tracking_mode <> 'quantity' or coalesce(v_item.quantity, 0) < 1 then raise exception 'Quantity item is invalid'; end if;
      select on_hand_quantity - reserved_quantity - rented_quantity into v_available from public.stock_balances where product_id = v_item.product_id for update;
      if coalesce(v_available, 0) < v_item.quantity then raise exception 'Insufficient quantity'; end if;
      update public.stock_balances set reserved_quantity = reserved_quantity + v_item.quantity where product_id = v_item.product_id;
      insert into public.rental_items (rental_id, product_id, quantity, daily_rate_snapshot) values (v_rental.id, v_item.product_id, v_item.quantity, v_product.daily_rate);
      insert into public.inventory_events (product_id, rental_id, event_type, quantity, created_by) values (v_item.product_id, v_rental.id, 'reserved', v_item.quantity, p_created_by);
    end if;
  end loop;
  return v_rental;
end $$;

create function public.checkout_rental(p_rental_id uuid, p_created_by uuid) returns public.rentals language plpgsql set search_path = '' as $$
declare v_rental public.rentals; v_item public.rental_items;
begin select * into v_rental from public.rentals where id=p_rental_id for update; if not found or v_rental.status <> 'reserved' then raise exception 'Rental is not reserved'; end if;
  for v_item in select * from public.rental_items where rental_id=p_rental_id loop
    if v_item.asset_id is not null then update public.assets set status='rented' where id=v_item.asset_id and status='reserved'; else update public.stock_balances set reserved_quantity=reserved_quantity-v_item.quantity, rented_quantity=rented_quantity+v_item.quantity where product_id=v_item.product_id; end if;
    insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by) values (v_item.product_id,v_item.asset_id,p_rental_id,'checked_out',v_item.quantity,p_created_by); end loop;
  update public.rentals set status='active' where id=p_rental_id returning * into v_rental; return v_rental; end $$;

create function public.return_rental(p_rental_id uuid, p_created_by uuid) returns public.rentals language plpgsql set search_path = '' as $$
declare v_rental public.rentals; v_item public.rental_items;
begin select * into v_rental from public.rentals where id=p_rental_id for update; if not found or v_rental.status <> 'active' then raise exception 'Rental is not active'; end if;
  for v_item in select * from public.rental_items where rental_id=p_rental_id loop
    if v_item.asset_id is not null then update public.assets set status='available' where id=v_item.asset_id and status='rented'; else update public.stock_balances set rented_quantity=rented_quantity-v_item.quantity where product_id=v_item.product_id; end if;
    update public.rental_items set returned_at=now() where id=v_item.id; insert into public.inventory_events (product_id, asset_id, rental_id, event_type, quantity, created_by) values (v_item.product_id,v_item.asset_id,p_rental_id,'returned',v_item.quantity,p_created_by); end loop;
  update public.rentals set status='returned' where id=p_rental_id returning * into v_rental; return v_rental; end $$;
