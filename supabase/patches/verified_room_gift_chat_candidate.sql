-- Staging candidate ONLY. DO NOT AUTO-APPLY.
-- Room gift messages must never be emitted from optimistic Flutter state.
-- A deferred database trigger observes the immutable, committed gift ledger.
-- No sample rooms, fake gifts, balance updates or production changes here.

begin;

alter table public.room_messages
 add column event_kind text not null default 'chat';
alter table public.room_messages
 add constraint room_message_event_kind_check
 check (event_kind in ('chat', 'gift'));
alter table public.room_messages
 add column gift_event_id uuid references public.gift_events(id);
create unique index room_messages_verified_gift_once
 on public.room_messages(gift_event_id);

alter table public.room_messages
 add constraint room_message_gift_origin_check
 check (
   (event_kind='chat' and gift_event_id is null) or
   (event_kind='gift' and gift_event_id is not null)
 );

create or replace function phase3.announce_verified_room_gift()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare
 sender_label text;
 recipient_label text;
 gift_label text;
 gift_icon text;
 safe_body text;
begin
 -- Financial RPC inserts gift_events only after it committed both balance
 -- mutations, but independently verify the final durable ledger rows.
 if not exists(
   select 1 from public.financial_operations f
   where f.id=new.id and f.operation='gift' and f.status='completed'
 ) then return new;end if;

 if not exists(
   select 1 from public.wallet_ledger l
   where l.transaction_id=new.id and l.user_id=new.sender_id
     and l.kind='gift_sent' and l.currency='coins'
     and l.amount_change=-new.amount
 ) then return new;end if;

 if not exists(
   select 1 from public.wallet_ledger l
   where l.transaction_id=new.id and l.user_id=new.recipient_id
     and l.kind='gift_received' and l.currency='diamonds'
     and l.amount_change=new.amount
 ) then return new;end if;

 select display_name into sender_label
 from public.profiles where id=new.sender_id;
 select display_name into recipient_label
 from public.profiles where id=new.recipient_id;
 select name,icon into gift_label,gift_icon
 from public.gift_catalog where id=new.gift_id;

 safe_body := left(
   coalesce(nullif(btrim(gift_icon),''),'🎁')
   || ' ' || coalesce(nullif(btrim(sender_label),''),'Member')
   || ' → ' || coalesce(nullif(btrim(recipient_label),''),'Member')
   || ': ' || coalesce(nullif(btrim(gift_label),''),'Gift')
   || ' × ' || new.quantity::text,
   500
 );

 -- Only one room-chat row can exist per settled gift operation. A client
 -- never receives INSERT permissions on room_messages or on this trigger.
 insert into public.room_messages(
   room_id,sender_id,body,event_kind,gift_event_id
 ) values(
   new.room_id,new.sender_id,safe_body,'gift',new.id
 ) on conflict(gift_event_id) do nothing;
 return new;
end $fn$;

revoke all on function phase3.announce_verified_room_gift()
 from public,anon,authenticated;

create constraint trigger tc_verified_room_gift_message
 after insert on public.gift_events
 deferrable initially deferred
 for each row execute function phase3.announce_verified_room_gift();

commit;
