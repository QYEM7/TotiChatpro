-- T64: Verified personal gift receipt ledger (read only).
-- Read actual committed gift_events; do not invent a transaction, balance,
-- diamonds, percentages, salaries, bonus or lucky payout.
create index if not exists tc_gifts_sender_cursor
 on public.gift_events(sender_id,created_at desc,id desc);
create index if not exists tc_gifts_recipient_cursor
 on public.gift_events(recipient_id,created_at desc,id desc);

create function phase3.personal_gift_summary()
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();sent_count bigint;received_count bigint;
 sent_coins numeric;received_coins numeric;received_lots numeric;
begin
 select count(*),coalesce(sum(e.amount),0)
 into sent_count,sent_coins from public.gift_events e
 join public.financial_operations fin on fin.id=e.id and fin.operation='gift' and fin.status='completed'
 where e.sender_id=me;
 select count(*),coalesce(sum(e.amount),0)
 into received_count,received_coins from public.gift_events e
 join public.financial_operations fin on fin.id=e.id and fin.operation='gift' and fin.status='completed'
 where e.recipient_id=me;
 select coalesce(sum(l.amount),0) into received_lots
 from public.diamond_lots l
 join public.gift_events e on e.id=l.gift_event_id
 join public.financial_operations fin on fin.id=e.id and fin.operation='gift' and fin.status='completed'
 where l.user_id=me and e.recipient_id=me;
 return jsonb_build_object('userId',me,'sentCount',sent_count,
   'receivedCount',received_count,'sentGiftCoins',sent_coins::text,
   'receivedGiftCoins',received_coins::text,
   'receivedGiftDiamonds',received_lots::text,
   'isAllTime',true,'isSalaryReport',false,'isBalance',false);
end $fn$;
revoke all on function phase3.personal_gift_summary() from public,anon;
grant execute on function phase3.personal_gift_summary() to authenticated;

create function phase3.personal_gift_history(
 p_direction text default 'received',p_limit integer default 25,
 p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();result jsonb;next_at timestamptz;
 next_id uuid;count_rows integer;
begin
 if p_direction is null or p_direction not in('received','sent','all')
   or p_limit is null or p_limit not between 1 and 50
   or (p_before_at is null)<>(p_before_id is null)
   or (p_before_at is not null and p_before_at>now()+interval '1 minute')
 then raise exception 'Invalid gift history page';end if;
 with rows as (
 select e.id,e.created_at,e.room_id,e.gift_id,
  c.name gift_name,c.icon gift_icon,e.quantity,
  e.amount::text gift_coins,e.diamond_source_type source_type,
  e.sender_id,e.recipient_id,
  case when e.sender_id=me then 'sent' else 'received' end direction,
  case when e.sender_id=me then e.recipient_id else e.sender_id end counterparty_id,
  p.display_name counterparty_name,
  l.amount::text delivered_diamonds
 from public.gift_events e
 join public.financial_operations fin on fin.id=e.id and fin.operation='gift' and fin.status='completed'
 join public.gift_catalog c on c.id=e.gift_id
 left join public.profiles p on p.id=
    (case when e.sender_id=me then e.recipient_id else e.sender_id end)
 left join public.diamond_lots l on l.gift_event_id=e.id and l.user_id=e.recipient_id
 where (p_direction='all' and (e.sender_id=me or e.recipient_id=me)
     or p_direction='sent' and e.sender_id=me
     or p_direction='received' and e.recipient_id=me)
   and (p_before_at is null or (e.created_at,e.id)<(p_before_at,p_before_id))
 order by e.created_at desc,e.id desc
 limit p_limit
 ), summary as(
  select coalesce(jsonb_agg(to_jsonb(rows) order by created_at desc,id desc),
  '[]'::jsonb) items,count(*)::integer row_count from rows)
 select items,row_count into result,count_rows from summary;
 select e.created_at,e.id into next_at,next_id
 from public.gift_events e
 join public.financial_operations fin on fin.id=e.id and fin.operation='gift' and fin.status='completed'
 where (p_direction='all' and (e.sender_id=me or e.recipient_id=me)
   or p_direction='sent' and e.sender_id=me
   or p_direction='received' and e.recipient_id=me)
 and (p_before_at is null or (e.created_at,e.id)<(p_before_at,p_before_id))
 order by e.created_at desc,e.id desc offset greatest(count_rows-1,0) limit 1;
 return jsonb_build_object('direction',p_direction,'items',result,
  'nextAt',case when count_rows=p_limit then next_at else null end,
  'nextId',case when count_rows=p_limit then next_id else null end);
end $fn$;
revoke all on function phase3.personal_gift_history(text,integer,timestamptz,uuid) from public,anon;
grant execute on function phase3.personal_gift_history(text,integer,timestamptz,uuid) to authenticated;

create function public.phase5_gift_summary()
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor(); return phase3.personal_gift_summary();end $fn$;
create function public.phase5_gift_history(
 p_direction text default 'received',p_limit integer default 25,
 p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor();
 return phase3.personal_gift_history(p_direction,p_limit,p_before_at,p_before_id);end $fn$;
revoke all on function public.phase5_gift_summary(),
 public.phase5_gift_history(text,integer,timestamptz,uuid) from public,anon;
grant execute on function public.phase5_gift_summary(),
 public.phase5_gift_history(text,integer,timestamptz,uuid) to authenticated;
comment on function public.phase5_gift_history(text,integer,timestamptz,uuid) is
 'Verified self-only committed gift receipts, keyset paging; no salary claims or wallet mutations.';
