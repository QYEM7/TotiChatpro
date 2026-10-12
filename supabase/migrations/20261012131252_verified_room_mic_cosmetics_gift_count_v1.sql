-- TotiChat Staging: server-authoritative seated VIP/frame/gift decorations
-- No wallet writes and no inferred awards. RPC requires current room membership.
create or replace function phase3.room_mic_decorations(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $body$
declare out_rows jsonb;
begin
  perform phase3.actor();
  if p_room_id is null or not exists(
    select 1 from public.room_members x
    where x.room_id=p_room_id and x.user_id=auth.uid()
  ) then raise exception 'Room membership required' using errcode='42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'userId',m.user_id,
    'vipTier',case when v.tier between 1 and 10 and
      (v.expires_at is null or v.expires_at>now()) then v.tier else 0 end,
    'frame',case when f.name is not null then
      jsonb_build_object('name',f.name,'icon',f.icon) else null end,
    'receivedGifts',coalesce(gifts.count,0)
  ) order by m.seat_no),'[]'::jsonb)
  into out_rows
  from public.room_members m
  left join public.vip_entitlements v on v.user_id=m.user_id
  left join lateral(
    select c.name,c.icon from public.store_ownership o
    join public.store_catalog c on c.id=o.item_id
    where o.user_id=m.user_id and o.equipped=true
      and (o.expires_at is null or o.expires_at>now())
      and c.is_active=true and c.category='frames'
    order by o.created_at desc,o.id desc limit 1
  ) f on true
  left join lateral(
    select count(*)::bigint count from public.gift_events e
    join public.financial_operations op on op.id=e.id
      and op.operation='gift' and op.status='completed'
    where e.room_id=p_room_id and e.recipient_id=m.user_id
  ) gifts on true
  where m.room_id=p_room_id and m.seat_no between 1 and 15;
  return out_rows;
end;
$body$;
revoke all on function phase3.room_mic_decorations(uuid) from public,anon;
grant execute on function phase3.room_mic_decorations(uuid) to authenticated;
create or replace function public.phase6_room_mic_decorations(p_room_id uuid)
returns jsonb language plpgsql security invoker set search_path = ''
as $body$
begin
  perform phase3.actor();
  return phase3.room_mic_decorations(p_room_id);
end;
$body$;
revoke all on function public.phase6_room_mic_decorations(uuid) from public,anon;
grant execute on function public.phase6_room_mic_decorations(uuid) to authenticated;