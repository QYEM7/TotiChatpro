-- Only broadcast a real gift after BOTH immutable financial ledger entries exist.
-- Constraint trigger runs at the end of the transaction, after the send_gift RPC
-- has inserted sender debit and recipient credit. Aborted transactions emit nothing.
create or replace function public.phase3_gift_announce_verified()
returns trigger language plpgsql security definer set search_path='' as $$
declare cfg public.gift_announcement_settings%rowtype; g public.gift_catalog%rowtype;
 sname text; rname text;
begin
 if not exists(select 1 from public.financial_operations op
  where op.id=new.id and op.operation='gift' and op.status='completed') then
   return new;
 end if;
 -- Prove the sender was debited for exactly this committed operation.
 if not exists(select 1 from public.wallet_ledger sender_ledger
  where sender_ledger.transaction_id=new.id and sender_ledger.user_id=new.sender_id
   and sender_ledger.kind='gift_sent' and sender_ledger.currency='coins'
   and sender_ledger.amount_change=-new.amount) then
   return new;
 end if;
 -- Prove the recipient was actually credited for exactly this operation.
 if not exists(select 1 from public.wallet_ledger recipient_ledger
  where recipient_ledger.transaction_id=new.id and recipient_ledger.user_id=new.recipient_id
   and recipient_ledger.kind='gift_received' and recipient_ledger.currency='diamonds'
   and recipient_ledger.amount_change=new.amount) then
   return new;
 end if;
 select * into cfg from public.gift_announcement_settings where singleton=true;
 if not found or not cfg.enabled or cfg.min_gift_price is null then return new;end if;
 select * into g from public.gift_catalog where id=new.gift_id;
 if not found or not g.global_announcement_enabled or g.price<cfg.min_gift_price then
  return new;
 end if;
 select display_name into sname from public.profiles where id=new.sender_id;
 select display_name into rname from public.profiles where id=new.recipient_id;
 insert into public.gift_global_announcements(
  id,room_id,sender_id,recipient_id,gift_id,gift_name,gift_icon,sender_name,
  recipient_name,quantity,unit_price,total_coins,created_at
 ) values(
  new.id,new.room_id,new.sender_id,new.recipient_id,new.gift_id,
  g.name,g.icon,coalesce(sname,'مستخدم'),coalesce(rname,'مستخدم'),
  new.quantity,g.price,new.amount,new.created_at
 ) on conflict(id) do nothing;
 return new;
end $$;
revoke all on function public.phase3_gift_announce_verified() from public,anon,authenticated;
drop trigger if exists tc_gift_announcement_after_payment on public.gift_events;
create constraint trigger tc_gift_announcement_after_payment
 after insert on public.gift_events
 deferrable initially deferred
 for each row execute function public.phase3_gift_announce_verified();
