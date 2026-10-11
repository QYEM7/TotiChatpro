-- T66: actual ledger-backed gift -> recipient-only in-app notification.
-- No user-authored notification insertion or duplicate after idempotent replay.
alter table public.user_notifications
 drop constraint if exists user_notifications_event_type_check;
alter table public.user_notifications
 add constraint user_notifications_event_type_check check(event_type in(
 'vip_granted','vip_revoked','room_moderator_granted','room_moderator_revoked',
 'room_kicked','room_banned','room_unbanned','room_muted','room_mic_allowed',
 'room_seat_released','support_staff_replied','medal_granted','medal_revoked',
 'gift_received'));

create function phase3.notification_on_verified_gift_audit()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare e public.gift_events%rowtype;fin public.financial_operations%rowtype;
begin
 if new.action<>'gift_sent' or new.operation_id is null or new.actor_id is null then
  return new;
 end if;
 select * into fin from public.financial_operations f
  where f.id=new.operation_id and f.operation='gift' and f.status='completed';
 if not found or fin.actor_id<>new.actor_id then return new;end if;
 select * into e from public.gift_events g
  where g.id=fin.id and g.sender_id=new.actor_id;
 if not found or e.recipient_id=new.actor_id then return new;end if;
 -- Source ID is the positive BIGINT security_audit primary key.
 -- Sender, amount and recipient are independently verified from committed
 -- backend gift rows, never arbitrary client-provided notification body.
 insert into public.user_notifications(recipient_id,event_type,source_type,source_id,context)
 values(e.recipient_id,'gift_received','security_audit',new.id,
  jsonb_build_object('giftId',e.gift_id,'senderId',e.sender_id,
   'quantity',e.quantity,'coinsAmount',e.amount::text,
   'roomId',e.room_id))
 on conflict(recipient_id,source_type,source_id) do nothing;
 return new;
end $fn$;
revoke all on function phase3.notification_on_verified_gift_audit() from public,anon,authenticated;
create trigger tc_notification_on_verified_gift_audit
 after insert on public.security_audit
 for each row
 when (new.action='gift_sent')
 execute function phase3.notification_on_verified_gift_audit();
comment on function phase3.notification_on_verified_gift_audit() is
 'Verified completed gift financial op, private recipient-only inbox, idempotent audit source.';
