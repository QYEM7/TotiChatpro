-- Staging backend: voice-room membership and issue-budget authorization only.
-- Tokens are minted by the Edge Function using server-side LiveKit secrets.
create table if not exists public.voice_token_rate_limits(
 user_id uuid primary key references auth.users(id),
 window_started timestamptz not null default now(),
 hits integer not null default 0 check(hits between 0 and 1000)
);
alter table public.voice_token_rate_limits enable row level security;
revoke all on public.voice_token_rate_limits from public,anon,authenticated;
create or replace function public.phase2_voice_token_preflight(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); s integer; muted boolean; now_time timestamptz:=now(); old public.voice_token_rate_limits%rowtype;
begin
 if caller is null or p_room_id is null then
  raise exception 'UNAUTHORIZED' using errcode='42501';end if;
 -- Do not issue permissions for a guessed or previously exited room.
 select m.seat_no,m.is_muted into s,muted
 from public.room_members m
 where m.user_id=caller and m.room_id=p_room_id
 for share;
 if not found then
  raise exception 'ROOM_MEMBERSHIP_REQUIRED' using errcode='42501';end if;
 perform pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('voice-token|'||caller::text,0));
 select * into old from public.voice_token_rate_limits where user_id=caller for update;
 if not found then
   insert into public.voice_token_rate_limits(user_id,window_started,hits)
    values(caller,now_time,1);
 elsif old.window_started < now_time-interval '1 minute' then
   update public.voice_token_rate_limits set window_started=now_time,hits=1 where user_id=caller;
 elsif old.hits>=20 then
   raise exception 'VOICE_RATE_LIMITED' using errcode='P0001';
 else
   update public.voice_token_rate_limits set hits=hits+1 where user_id=caller;
 end if;
 return jsonb_build_object('roomId',p_room_id,'canPublish',(s is not null and muted=false));
end $$;
revoke all on function public.phase2_voice_token_preflight(uuid) from public,anon;
grant execute on function public.phase2_voice_token_preflight(uuid) to authenticated;
