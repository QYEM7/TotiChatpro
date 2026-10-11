-- TotiChat pre-release: a private, source-backed in-app notification inbox.
-- Notification rows are minted ONLY by verified committed server-side events.
-- No FCM credentials, promotional messages, fake test notifications or balances.
create table public.user_notifications (
 id bigint generated always as identity primary key,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 event_type text not null check(event_type in (
 'vip_granted','vip_revoked','room_moderator_granted','room_moderator_revoked',
 'room_kicked','room_banned','room_unbanned','room_muted','room_mic_allowed',
 'room_seat_released','support_staff_replied')),
 source_type text not null check(source_type in ('security_audit','support_message')),
 source_id bigint not null check(source_id>0),
 context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'
   and octet_length(context::text)<=2048),
 created_at timestamptz not null default now(),
 read_at timestamptz,
 constraint tc_notification_unique_source unique (recipient_id,source_type,source_id)
);
create index tc_notification_user_newest on public.user_notifications(recipient_id,id desc);
create index tc_notification_unread on public.user_notifications(recipient_id,id desc)
 where read_at is null;
alter table public.user_notifications enable row level security;
revoke all on public.user_notifications from public,anon,authenticated;
-- Postgres Changes / Realtime can deliver this inbox to its owner, and
-- clients cannot INSERT/UPDATE/DELETE or enumerate another account's inbox.
grant select on public.user_notifications to authenticated;
create policy tc_notification_owner_read on public.user_notifications
 for select to authenticated using(recipient_id=(select auth.uid()));

create function phase3.notification_on_audit()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare kind text;target uuid;target_text text;cid text;
begin
 kind:=case new.action
 when 'vip_grant' then 'vip_granted'
 when 'vip_revoke' then 'vip_revoked'
 when 'room_moderation_grant_moderator' then 'room_moderator_granted'
 when 'room_moderation_revoke_moderator' then 'room_moderator_revoked'
 when 'room_moderation_kick' then 'room_kicked'
 when 'room_moderation_ban' then 'room_banned'
 when 'room_moderation_unban' then 'room_unbanned'
 when 'room_moderation_mute' then 'room_muted'
 when 'room_moderation_allow_mic' then 'room_mic_allowed'
 when 'room_moderation_release_seat' then 'room_seat_released'
 else null end;
 if kind is null then return new;end if;
 -- Audit is written by an authorized backend operation. Only a valid target
 -- is converted into UUID, never an arbitrary nested user-supplied field.
 target_text:=new.details->>'targetId';
 if target_text is null or target_text !~
  '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  then return new;end if;
 target:=target_text::uuid;
 if target=new.actor_id then return new;end if;
 cid:=new.details->>'roomId';
 insert into public.user_notifications(recipient_id,event_type,source_type,source_id,context)
 values(target,kind,'security_audit',new.id,
  case when kind like 'vip_%' then
    jsonb_build_object('tier',new.details->'tier','expiresAt',new.details->'expiresAt')
   else jsonb_build_object('roomId',cid) end)
 on conflict(recipient_id,source_type,source_id) do nothing;
 return new;
end $fn$;
revoke all on function phase3.notification_on_audit() from public,anon,authenticated;
create trigger tc_notification_audit
 after insert on public.security_audit for each row
 execute function phase3.notification_on_audit();

-- Support reply notification deliberately contains NO subject/message/plaintext.
-- It is sent ONLY when the verified handler replies to the ticket creator.
create function phase3.notification_on_support_reply()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare owner uuid;
begin
 select t.creator_id into owner from public.support_tickets t where t.id=new.ticket_id;
 if owner is null or new.author_id=owner then return new;end if;
 insert into public.user_notifications(recipient_id,event_type,source_type,source_id,context)
 values(owner,'support_staff_replied','support_message',new.id,
   jsonb_build_object('ticketId',new.ticket_id))
 on conflict(recipient_id,source_type,source_id) do nothing;
 return new;
end $fn$;
revoke all on function phase3.notification_on_support_reply() from public,anon,authenticated;
create trigger tc_notification_support_reply
 after insert on public.support_messages for each row
 execute function phase3.notification_on_support_reply();

-- Private read RPC, verified user/session, cursor-bound and bounded result size.
create function phase3.notification_feed(p_limit integer default 30,p_before bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare caller uuid:=phase3.actor();items jsonb;unread bigint;
begin
 if p_limit is null or p_limit not between 1 and 50 or
  (p_before is not null and p_before<1) then
  raise exception 'Invalid notification page';
 end if;
 select coalesce(jsonb_agg(to_jsonb(v) order by v.id desc),'[]'::jsonb)
 into items from (
  select id,event_type,context,created_at,read_at
  from public.user_notifications
  where recipient_id=caller and (p_before is null or id<p_before)
  order by id desc limit p_limit
 ) v;
 select count(*) into unread from public.user_notifications
 where recipient_id=caller and read_at is null;
 return jsonb_build_object('items',items,'unreadCount',unread);
end $fn$;
revoke all on function phase3.notification_feed(integer,bigint) from public,anon;
grant execute on function phase3.notification_feed(integer,bigint) to authenticated;

create function phase3.notification_mark(p_ids bigint[] default array[]::bigint[],p_all boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare caller uuid:=phase3.actor();changed integer;
begin
 if p_all is null or p_ids is null or cardinality(p_ids)>100 or
  exists(select 1 from unnest(p_ids) id where id is null or id<1) then
  raise exception 'Invalid notification acknowledgment';
 end if;
 if p_all then
  update public.user_notifications set read_at=now()
  where recipient_id=caller and read_at is null;
 else
  update public.user_notifications set read_at=now()
  where recipient_id=caller and read_at is null and id=any(p_ids);
 end if;
 get diagnostics changed=row_count;
 return jsonb_build_object('updated',changed);
end $fn$;
revoke all on function phase3.notification_mark(bigint[],boolean) from public,anon;
grant execute on function phase3.notification_mark(bigint[],boolean) to authenticated;

create function public.phase5_notification_feed(p_limit integer default 30,p_before bigint default null)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.notification_feed(p_limit,p_before);
end $fn$;
create function public.phase5_notification_mark(p_ids bigint[] default array[]::bigint[],p_all boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.notification_mark(p_ids,p_all);
end $fn$;
revoke all on function public.phase5_notification_feed(integer,bigint),
 public.phase5_notification_mark(bigint[],boolean) from public,anon;
grant execute on function public.phase5_notification_feed(integer,bigint),
 public.phase5_notification_mark(bigint[],boolean) to authenticated;

-- Live updates of only the owner's RLS-approved notification rows.
do $pub$
begin
 if exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime')
 and not exists(select 1 from pg_catalog.pg_publication_tables
   where pubname='supabase_realtime' and schemaname='public' and tablename='user_notifications')
 then alter publication supabase_realtime add table public.user_notifications;end if;
end $pub$;
comment on table public.user_notifications is
 'Private server-generated transactional events only. Realtime INSERT + cursor RPC; mobile OS push delivery requires separately configured FCM/APNs.';
