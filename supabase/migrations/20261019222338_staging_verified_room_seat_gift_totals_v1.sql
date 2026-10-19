-- Applied to Supabase Staging rziaedugbdwefbefcxjt as migration 20261019222338_staging_verified_room_seat_gift_totals_v1.
-- No wallet mutations. Never apply to production without separate review.
-- STAGING candidate only. Do not auto-apply or deploy to production.
-- Gift value displayed below active seats comes from SETTLED gifts in this
-- room, not the recipient's private wallet, arbitrary user metadata or
-- optimistic events from a Flutter client.
begin;

create or replace function phase3.room_seat_verified_gift_totals(
  p_room_id uuid
)
returns table(user_id uuid, total_coins bigint)
language plpgsql security definer set search_path='' as $body$
declare caller_id uuid;
begin
  caller_id := phase3.actor();
  if p_room_id is null or not exists(
    select 1 from public.room_members m
    where m.room_id=p_room_id and m.user_id=caller_id
  ) then
    raise exception 'ROOM_MEMBERSHIP_REQUIRED' using errcode='42501';
  end if;

  return query
  select m.user_id,
    coalesce((
      select sum(g.amount)::bigint
      from public.gift_events g
      join public.financial_operations f
        on f.id=g.id and f.operation='gift' and f.status='completed'
      where g.room_id=p_room_id
        and g.recipient_id=m.user_id
        and g.amount > 0
        and exists(
          select 1 from public.wallet_ledger sender_debit
          where sender_debit.transaction_id=g.id
            and sender_debit.user_id=g.sender_id
            and sender_debit.currency='coins'
            and sender_debit.kind='gift_sent'
            and sender_debit.amount_change=-g.amount
        )
        and exists(
          select 1 from public.wallet_ledger recipient_credit
          where recipient_credit.transaction_id=g.id
            and recipient_credit.user_id=g.recipient_id
            and recipient_credit.currency='diamonds'
            and recipient_credit.kind='gift_received'
            and recipient_credit.amount_change=g.amount
        )
    ),0::bigint) as total_coins
  from public.room_members m
  where m.room_id=p_room_id and m.seat_no between 1 and 15
  order by m.seat_no;
end $body$;

-- phase3 is not exposed through the PostgREST API. Even when called directly
-- in SQL, membership and session checks still guard all results.
revoke all on function phase3.room_seat_verified_gift_totals(uuid)
 from public,anon,authenticated;
grant execute on function phase3.room_seat_verified_gift_totals(uuid)
 to authenticated;

create or replace function public.phase2_room_seat_gift_totals(
  p_room_id uuid
)
returns table(user_id uuid,total_coins bigint)
language sql security invoker set search_path='' as $body$
  select * from phase3.room_seat_verified_gift_totals(p_room_id)
$body$;

revoke all on function public.phase2_room_seat_gift_totals(uuid)
 from public,anon,authenticated;
grant execute on function public.phase2_room_seat_gift_totals(uuid)
 to authenticated;

commit;
