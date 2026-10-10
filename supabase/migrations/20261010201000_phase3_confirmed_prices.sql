-- Never charge a price different from the one the user explicitly confirmed.
create function phase3.send_gift_checked(p_room_id uuid,p_recipient_id uuid,p_gift_id text,p_quantity integer,p_request_id uuid,p_expected_price bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); actual bigint; prior public.financial_operations%rowtype;
begin
 -- Replays must keep working even if the catalog price changed after completion.
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if not found then
  select price into actual from public.gift_catalog where id=p_gift_id and is_active for share;
  if p_expected_price is null or actual is null or actual<>p_expected_price then raise exception 'Price changed; refresh and confirm again';end if;
 end if;
 return phase3.send_gift(p_room_id,p_recipient_id,p_gift_id,p_quantity,p_request_id);
end $$;
create function phase3.purchase_store_checked(p_item_id text,p_request_id uuid,p_expected_price bigint,p_expected_currency text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); price bigint;currency text;prior public.financial_operations%rowtype;
begin
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if not found then
  select c.price,c.currency into price,currency from public.store_catalog c where id=p_item_id and is_active for share;
  if p_expected_price is null or p_expected_currency is null or price is null or price<>p_expected_price or currency<>p_expected_currency then raise exception 'Price changed; refresh and confirm again';end if;
 end if;
 return phase3.purchase_store(p_item_id,p_request_id);
end $$;
revoke all on function phase3.send_gift(uuid,uuid,text,integer,uuid),phase3.purchase_store(text,uuid) from authenticated;
revoke all on function phase3.send_gift_checked(uuid,uuid,text,integer,uuid,bigint),phase3.purchase_store_checked(text,uuid,bigint,text) from public,anon;
grant execute on function phase3.send_gift_checked(uuid,uuid,text,integer,uuid,bigint),phase3.purchase_store_checked(text,uuid,bigint,text) to authenticated;
drop function public.phase3_send_gift(uuid,uuid,text,integer,uuid);
drop function public.phase3_purchase_store(text,uuid);
create function public.phase3_send_gift(p_room_id uuid,p_recipient_id uuid,p_gift_id text,p_quantity integer,p_request_id uuid,p_expected_price bigint) returns jsonb language sql security invoker set search_path='' as $$select phase3.send_gift_checked(p_room_id,p_recipient_id,p_gift_id,p_quantity,p_request_id,p_expected_price)$$;
create function public.phase3_purchase_store(p_item_id text,p_request_id uuid,p_expected_price bigint,p_expected_currency text) returns jsonb language sql security invoker set search_path='' as $$select phase3.purchase_store_checked(p_item_id,p_request_id,p_expected_price,p_expected_currency)$$;
revoke all on function public.phase3_send_gift(uuid,uuid,text,integer,uuid,bigint),public.phase3_purchase_store(text,uuid,bigint,text) from public,anon;
grant execute on function public.phase3_send_gift(uuid,uuid,text,integer,uuid,bigint),public.phase3_purchase_store(text,uuid,bigint,text) to authenticated;
