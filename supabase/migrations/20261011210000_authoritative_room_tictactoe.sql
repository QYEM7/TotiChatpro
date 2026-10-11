-- T63: authoritative, no-stakes room tic-tac-toe. No fake player,
-- wallet mutation, voice interruption or bet/payout path.
create table public.room_game_matches(
 id uuid primary key default gen_random_uuid(),
 match_order bigint generated always as identity unique,
 room_id uuid not null references public.rooms(id) on delete cascade,
 game_type text not null default 'tic_tac_toe'
  check(game_type='tic_tac_toe'),
 player_x uuid not null references auth.users(id) on delete cascade,
 player_o uuid references auth.users(id) on delete cascade,
 board text not null default '.........' check(board~'^[XO.]{9}$'),
 next_mark text not null default 'X' check(next_mark in('X','O')),
 turn_no integer not null default 0 check(turn_no between 0 and 9),
 status text not null default 'waiting'
   check(status in('waiting','active','won','draw','cancelled')),
 winner_id uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint tc_room_game_different_players check(player_x is distinct from player_o)
);
create unique index tc_one_active_game_per_room
 on public.room_game_matches(room_id)
 where status in ('waiting','active');
create index tc_room_game_recent on public.room_game_matches(room_id,created_at desc);
alter table public.room_game_matches enable row level security;
revoke all on public.room_game_matches from public,anon,authenticated;

create table phase3.room_game_requests(
 actor_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null,
 room_id uuid not null,
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index tc_room_game_rate on phase3.room_game_requests(actor_id,created_at desc);
alter table phase3.room_game_requests enable row level security;
revoke all on phase3.room_game_requests from public,anon,authenticated;

-- Privileged because clients must never modify authoritative board cells.
-- Every read checks verified live session AND current membership.
create function phase3.room_game_state(p_room_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();game public.room_game_matches%rowtype;
begin
 if p_room_id is null or not exists(select 1 from public.room_members
   where room_id=p_room_id and user_id=me) then
  raise exception 'Join this room to view the game' using errcode='42501';
 end if;
 select * into game from public.room_game_matches
 where room_id=p_room_id
 order by (status in('waiting','active')) desc,match_order desc
 limit 1;
 if not found then
  return jsonb_build_object('hasGame',false,'roomId',p_room_id);
 end if;
 return jsonb_build_object('hasGame',true,'roomId',p_room_id,
  'gameId',game.id,'type',game.game_type,'playerX',game.player_x,
  'playerO',game.player_o,'board',game.board,'nextMark',game.next_mark,
  'turnNo',game.turn_no,'status',game.status,'winnerId',game.winner_id,
  'updatedAt',game.updated_at);
end $fn$;
revoke all on function phase3.room_game_state(uuid) from public,anon;
grant execute on function phase3.room_game_state(uuid) to authenticated;

create function phase3.room_game_action(
 p_room_id uuid,p_action text,p_cell integer,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();
 current_game public.room_game_matches%rowtype;
 prior phase3.room_game_requests%rowtype;payload jsonb;
 result jsonb;room_owner uuid;marker text;next_board text;has_won boolean;
begin
 if p_room_id is null or p_request_id is null
  or p_action is null or p_action not in('start','join','move','cancel')
  or (p_action='move' and (p_cell is null or p_cell not between 0 and 8))
  or (p_action<>'move' and p_cell is not null) then
  raise exception 'Invalid game action';
 end if;
 select owner_id into room_owner from public.rooms where id=p_room_id;
 if not found or not exists(select 1 from public.room_members m
   where m.room_id=p_room_id and m.user_id=me) then
  raise exception 'Join room before playing' using errcode='42501';
 end if;
 -- Serialize ALL actions (including starts, joins and moves) per room.
 perform pg_advisory_xact_lock(pg_catalog.hashtextextended('tc_room_game:'||p_room_id::text,0));
 payload:=jsonb_build_object('roomId',p_room_id,'action',p_action,'cell',p_cell);
 select * into prior from phase3.room_game_requests r
 where r.actor_id=me and r.request_id=p_request_id;
 if found then
  if prior.payload<>payload then
   raise exception 'Game idempotency request conflict';
  end if;
  return prior.result;
 end if;
 if (select count(*) from phase3.room_game_requests r
  where r.actor_id=me and r.created_at>now()-interval '1 minute')>=40 then
  raise exception 'Game actions rate limited';
 end if;
 select * into current_game from public.room_game_matches g
 where g.room_id=p_room_id and g.status in('waiting','active')
 order by g.match_order desc limit 1 for update;
 if p_action='start' then
  if found then raise exception 'A room game is already active';end if;
  insert into public.room_game_matches(room_id,player_x)
  values(p_room_id,me);
 elsif p_action='join' then
  if not found or current_game.status<>'waiting' or current_game.player_x=me then
   raise exception 'No joinable opponent game';
  end if;
  update public.room_game_matches set player_o=me,
   status='active',updated_at=now()
   where id=current_game.id;
 elsif p_action='move' then
  if not found or current_game.status<>'active' or
   me not in(current_game.player_x,current_game.player_o) then
   raise exception 'You are not an active game player' using errcode='42501';
  end if;
  marker:=case when current_game.player_x=me then 'X' else 'O' end;
  if current_game.next_mark<>marker then
   raise exception 'Not your turn';
  end if;
  if substring(current_game.board from p_cell+1 for 1)<>'.' then
   raise exception 'This square is occupied';
  end if;
  next_board:=overlay(current_game.board placing marker from p_cell+1 for 1);
  select coalesce(bool_or(
   substring(next_board from t.a for 1)=marker and
   substring(next_board from t.b for 1)=marker and
   substring(next_board from t.c for 1)=marker),false)
  into has_won from (values(1,2,3),(4,5,6),(7,8,9),
   (1,4,7),(2,5,8),(3,6,9),(1,5,9),(3,5,7)) as t(a,b,c);
  update public.room_game_matches set board=next_board,turn_no=turn_no+1,
   status=case when has_won then 'won'
               when current_game.turn_no=8 then 'draw' else 'active' end,
   winner_id=case when has_won then me else null end,
   next_mark=case when marker='X' then 'O' else 'X' end,
   updated_at=now()
  where id=current_game.id;
 elsif p_action='cancel' then
  if not found or me not in(current_game.player_x,
    coalesce(current_game.player_o,current_game.player_x),room_owner) then
   raise exception 'Only a player or room Owner can cancel' using errcode='42501';
  end if;
  update public.room_game_matches set status='cancelled',updated_at=now()
  where id=current_game.id;
 end if;
 result:=phase3.room_game_state(p_room_id);
 insert into phase3.room_game_requests(actor_id,request_id,room_id,payload,result)
 values(me,p_request_id,p_room_id,payload,result);
 return result;
end $fn$;
revoke all on function phase3.room_game_action(uuid,text,integer,uuid) from public,anon;
grant execute on function phase3.room_game_action(uuid,text,integer,uuid) to authenticated;

-- A player leaving the voice room invalidates their active game, but NEVER
-- removes their mic seat or disconnects anyone's media for a game action.
create function phase3.room_game_member_departure()
returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 update public.room_game_matches g set status='cancelled',updated_at=now()
 where g.room_id=old.room_id and g.status in('waiting','active')
  and (g.player_x=old.user_id or g.player_o=old.user_id);
 return old;
end $fn$;
revoke all on function phase3.room_game_member_departure() from public,anon,authenticated;
create trigger tc_game_cancel_on_member_departure
 after delete on public.room_members for each row
 execute function phase3.room_game_member_departure();

create function public.phase5_room_game_state(p_room_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.room_game_state(p_room_id);
end $fn$;
create function public.phase5_room_game_action(
 p_room_id uuid,p_action text,p_cell integer,p_request_id uuid
) returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.room_game_action(p_room_id,p_action,p_cell,p_request_id);
end $fn$;
revoke all on function public.phase5_room_game_state(uuid),
 public.phase5_room_game_action(uuid,text,integer,uuid) from public,anon;
grant execute on function public.phase5_room_game_state(uuid),
 public.phase5_room_game_action(uuid,text,integer,uuid) to authenticated;
comment on table public.room_game_matches is
 'No-stakes synchronized tic-tac-toe only, authorized present room members. No monetary or LiveKit actions.';
