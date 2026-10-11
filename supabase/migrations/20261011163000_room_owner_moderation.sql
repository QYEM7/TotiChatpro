-- TotiChat Phase 2: authentic room moderation, not a simulated UI.
-- Forward-only on isolated Staging; the approved 15-seat UI stays untouched.
-- Owner appoints/revokes room moderators. Moderators may enforce/release mute, release seats,
-- or kick ordinary members. Only the Owner may ban/unban or change moderators.
-- A short-lived LiveKit JWT is not equivalent to instant SFU-side revocation.
-- A moderated member cannot unmute via the existing self-service RPC.
-- This flag is independent of the user's own mute preference.
alter table public.room_members
 add column moderation_muted boolean not null default false;

create or replace function phase3.phase2_room_set_muted(p_room_id uuid,p_muted boolean)
returns boolean language plpgsql security definer set search_path='' as $fn$
declare uid uuid;seat integer;admin_muted boolean;
begin
 uid:=auth.uid();
 if uid is null then raise exception 'authentication required';end if;
 select seat_no,moderation_muted into seat,admin_muted
 from public.room_members where room_id=p_room_id and user_id=uid for update;
 if not found then raise exception 'join the room first';end if;
 if p_muted is not true and seat is null then raise exception 'take a seat first';end if;
 if p_muted is not true and admin_muted then
  raise exception 'ROOM_MODERATOR_MUTED' using errcode='42501';
 end if;
 update public.room_members set is_muted=coalesce(p_muted,true)
 where room_id=p_room_id and user_id=uid;
 return coalesce(p_muted,true);
end $fn$;

create table public.room_moderators(
 room_id uuid not null,
 user_id uuid not null,
 assigned_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 primary key(room_id,user_id),
 foreign key(room_id,user_id) references public.room_members(room_id,user_id) on delete cascade
);
create index tc_room_moderators_user on public.room_moderators(user_id);

create table public.room_bans(
 room_id uuid not null references public.rooms(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 banned_by uuid not null references auth.users(id),
 reason text not null check(char_length(btrim(reason)) between 5 and 300),
 created_at timestamptz not null default now(),
 primary key(room_id,user_id)
);
create index tc_room_bans_user on public.room_bans(user_id);

-- Persist moderator mute when a participant disconnects and rejoins the same room.
-- A moderator may not lift a restriction set by the room Owner.
create table public.room_mutes(
 room_id uuid not null references public.rooms(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 muted_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 primary key(room_id,user_id)
);
create index tc_room_mutes_user on public.room_mutes(user_id);

create table phase3.room_moderation_requests(
 actor_id uuid not null references auth.users(id),
 request_id uuid not null,
 room_id uuid not null references public.rooms(id) on delete cascade,
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index tc_room_moderation_requests_age
 on phase3.room_moderation_requests(actor_id,created_at desc);

alter table public.room_moderators enable row level security;
alter table public.room_bans enable row level security;
alter table public.room_mutes enable row level security;
alter table phase3.room_moderation_requests enable row level security;
revoke all on public.room_moderators,public.room_bans,public.room_mutes,phase3.room_moderation_requests
 from public,anon,authenticated;

-- Covers BOTH public join and one-time private invite join atomically. Existing
-- room join functions lock the room row FOR SHARE; moderation takes FOR UPDATE.
create function phase3.reject_banned_room_join()
returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 if exists(select 1 from public.room_bans b
  where b.room_id=new.room_id and b.user_id=new.user_id) then
    raise exception 'ROOM_BANNED' using errcode='42501';
 end if;
 if exists(select 1 from public.room_mutes m
   where m.room_id=new.room_id and m.user_id=new.user_id) then
  new.moderation_muted:=true;
  new.is_muted:=true;
 end if;
 return new;
end $fn$;
revoke all on function phase3.reject_banned_room_join() from public,anon,authenticated;
create trigger tc_room_ban_on_join
 before insert on public.room_members for each row
 execute function phase3.reject_banned_room_join();

create function phase3.room_moderation_action(
 p_room_id uuid,p_target uuid,p_action text,p_request_id uuid,p_reason text default null
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
 caller uuid:=phase3.actor();
 owner uuid;
 owner_action boolean;
 actor_mod boolean;
 target_mod boolean;
 reason_text text:=btrim(coalesce(p_reason,''));
 payload jsonb;
 previous phase3.room_moderation_requests%rowtype;
 result jsonb;
begin
 if p_room_id is null or p_target is null or p_request_id is null
  or p_action is null or p_action not in
   ('grant_moderator','revoke_moderator','kick','ban','unban','mute','allow_mic','release_seat')
  or octet_length(coalesce(p_reason,''))>1000 then
   raise exception 'Invalid room moderation action';
 end if;
 -- The lock also serializes with the FOR SHARE taken by public/private joins.
 select r.owner_id into owner from public.rooms r where r.id=p_room_id for update;
 if not found then raise exception 'Room unavailable' using errcode='42501';end if;
 owner_action:=owner=caller;
 actor_mod:=exists(select 1 from public.room_moderators m
   where m.room_id=p_room_id and m.user_id=caller);
 if not owner_action and not actor_mod then
  raise exception 'Room moderator permission required' using errcode='42501';
 end if;
 if p_target=owner or p_target=caller then
  raise exception 'Cannot moderate room owner or yourself' using errcode='42501';
 end if;
 target_mod:=exists(select 1 from public.room_moderators m
  where m.room_id=p_room_id and m.user_id=p_target);
 if not owner_action and (target_mod or p_action in
  ('grant_moderator','revoke_moderator','ban','unban')) then
  raise exception 'Owner permission required' using errcode='42501';
 end if;
 if p_action='ban' and char_length(reason_text) not between 5 and 300 then
  raise exception 'Documented ban reason required';
 end if;
 payload:=jsonb_build_object('room',p_room_id,'target',p_target,
   'action',p_action,'reason',reason_text);
 select * into previous from phase3.room_moderation_requests t
  where t.actor_id=caller and t.request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception 'Moderation idempotency key conflict';end if;
  return previous.result;
 end if;
 if (select count(*) from phase3.room_moderation_requests t
    where t.actor_id=caller and t.created_at>now()-interval '1 minute')>=30 then
  raise exception 'Moderation rate limit exceeded';
 end if;
 if p_action not in ('unban','allow_mic') and not exists(select 1 from public.room_members m
   where m.room_id=p_room_id and m.user_id=p_target for update) then
  raise exception 'Target is not a room member';
 end if;
 if p_action='grant_moderator' then
  insert into public.room_moderators(room_id,user_id,assigned_by)
   values(p_room_id,p_target,caller) on conflict(room_id,user_id) do nothing;
 elsif p_action='revoke_moderator' then
  delete from public.room_moderators where room_id=p_room_id and user_id=p_target;
 elsif p_action='mute' then
  -- Persist the restriction even if the member voluntarily leaves and rejoins.
  insert into public.room_mutes(room_id,user_id,muted_by)
    values(p_room_id,p_target,caller)
    on conflict(room_id,user_id) do update
    set muted_by=excluded.muted_by,created_at=now();
  update public.room_members set is_muted=true,moderation_muted=true
  where room_id=p_room_id and user_id=p_target;
 elsif p_action='allow_mic' then
  if not owner_action and exists(select 1 from public.room_mutes m
   where m.room_id=p_room_id and m.user_id=p_target and m.muted_by=owner) then
    raise exception 'Owner mute may be released only by owner' using errcode='42501';
  end if;
  delete from public.room_mutes where room_id=p_room_id and user_id=p_target;
  -- Never publish another person's microphone without their own action.
  update public.room_members set is_muted=true,moderation_muted=false
  where room_id=p_room_id and user_id=p_target;
 elsif p_action='release_seat' then
  update public.room_members set is_muted=true,seat_no=null
  where room_id=p_room_id and user_id=p_target;
 elsif p_action='kick' then
  delete from public.room_members where room_id=p_room_id and user_id=p_target;
 elsif p_action='ban' then
  insert into public.room_bans(room_id,user_id,banned_by,reason)
   values(p_room_id,p_target,caller,reason_text)
   on conflict(room_id,user_id) do nothing;
  delete from public.room_members where room_id=p_room_id and user_id=p_target;
 elsif p_action='unban' then
  delete from public.room_bans where room_id=p_room_id and user_id=p_target;
 end if;
 result:=jsonb_build_object('roomId',p_room_id,'targetId',p_target,
  'action',p_action,'success',true);
 insert into phase3.room_moderation_requests(actor_id,request_id,room_id,payload,result)
  values(caller,p_request_id,p_room_id,payload,result);
 insert into public.security_audit(actor_id,action,details)
  values(caller,'room_moderation_'||p_action,
  jsonb_build_object('roomId',p_room_id,'targetId',p_target,
   'requestId',p_request_id,'reason',case when p_action='ban' then reason_text else null end));
 return result;
end $fn$;
revoke all on function phase3.room_moderation_action(uuid,uuid,text,uuid,text)
 from public,anon;
grant execute on function phase3.room_moderation_action(uuid,uuid,text,uuid,text) to authenticated;

create function public.phase2_room_moderate(
 p_room_id uuid,p_target uuid,p_action text,p_request_id uuid,p_reason text default null
) returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.room_moderation_action(p_room_id,p_target,p_action,p_request_id,p_reason);
end $fn$;
revoke all on function public.phase2_room_moderate(uuid,uuid,text,uuid,text) from public,anon;
grant execute on function public.phase2_room_moderate(uuid,uuid,text,uuid,text) to authenticated;

-- A bounded, authenticated owner-only roster. No direct client SELECT grants.
create function public.phase2_room_moderation_state(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare caller uuid:=phase3.actor(); moderators jsonb;bans jsonb;
begin
 if p_room_id is null or not exists(select 1 from public.rooms r
    where r.id=p_room_id and r.owner_id=caller) then
   raise exception 'Room owner required' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object('userId',user_id,
  'assignedAt',created_at)),'[]'::jsonb) into moderators
 from public.room_moderators where room_id=p_room_id;
 select coalesce(jsonb_agg(jsonb_build_object('userId',user_id,
  'reason',reason,'createdAt',created_at)),'[]'::jsonb) into bans
 from (select user_id,reason,created_at from public.room_bans
   where room_id=p_room_id order by created_at desc limit 100) b;
 return jsonb_build_object('roomId',p_room_id,'moderators',moderators,'bans',bans);
end $fn$;
revoke all on function public.phase2_room_moderation_state(uuid) from public,anon;
grant execute on function public.phase2_room_moderation_state(uuid) to authenticated;

comment on table public.room_mutes is
 'Server-mandated microphone restriction persists across membership cycles until an authorized room moderation action clears it.';
comment on table public.room_bans is
 'Owner-issued per-room bans enforced on public and private membership INSERT. LiveKit SFU session revocation remains a separate release prerequisite.';
