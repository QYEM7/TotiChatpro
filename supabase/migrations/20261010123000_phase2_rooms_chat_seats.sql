-- TotiChat phase 2: secure foundation for real room directory, room membership,
-- microphone SEAT RESERVATIONS (not audio), and persistent text room chat.
-- This database is independent; legacy rooms and balances are NEVER imported.
create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  is_private boolean not null default false,
  created_at timestamptz not null default now(),
  constraint phase2_room_title_len check (char_length(btrim(title)) between 2 and 60)
);
create index phase2_rooms_created on public.rooms(created_at desc);
create index phase2_rooms_owner on public.rooms(owner_id);

create table public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  seat_no integer,
  is_muted boolean not null default true,
  primary key (room_id,user_id),
  constraint phase2_seat_range check (seat_no is null or seat_no between 1 and 15),
  -- One live room membership per account, including the room owner.
  constraint phase2_single_live_room unique(user_id)
);
create unique index phase2_unique_occupied_seat on public.room_members(room_id,seat_no)
  where seat_no is not null;
create index phase2_room_members_joined on public.room_members(room_id,joined_at);

create table public.room_messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint phase2_message_len check (char_length(btrim(body)) between 1 and 500)
);
create index phase2_room_messages_history on public.room_messages(room_id,created_at desc);

alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_messages enable row level security;
revoke all on public.rooms,public.room_members,public.room_messages from public,anon,authenticated;
grant select on public.rooms,public.room_members,public.room_messages to authenticated;
grant usage,select on sequence public.room_messages_id_seq to authenticated;

create policy "Only authenticated users see public or owned rooms"
on public.rooms for select to authenticated
using (not is_private or owner_id=(select auth.uid()));

create policy "Members see their own joined room membership"
on public.room_members for select to authenticated
using (user_id=(select auth.uid()));

create policy "Members see only messages of their joined rooms"
on public.room_messages for select to authenticated
using (exists(
  select 1 from public.room_members m
  where m.room_id=room_messages.room_id and m.user_id=(select auth.uid())
));

create function public.phase2_room_create(p_title text,p_is_private boolean default false)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare caller uuid; created uuid;
begin
 caller:=auth.uid();
 if caller is null then raise exception 'not authenticated';end if;
 if p_title is null or char_length(btrim(p_title)) not between 2 and 60
 then raise exception 'invalid room name';end if;
 if exists(select 1 from public.room_members where user_id=caller)
 then raise exception 'leave your current room first';end if;
 insert into public.rooms(owner_id,title,is_private)
 values(caller,btrim(p_title),coalesce(p_is_private,false))
 returning id into created;
 insert into public.room_members(room_id,user_id) values(created,caller);
 return created;
end;
$$;

create function public.phase2_room_join(p_room_id uuid)
returns boolean
language plpgsql security definer set search_path=''
as $$
declare caller uuid; r public.rooms%rowtype;
begin
 caller:=auth.uid();
 if caller is null then raise exception 'not authenticated';end if;
 select * into r from public.rooms where id=p_room_id for share;
 if not found then raise exception 'room does not exist';end if;
 if r.is_private and r.owner_id<>caller then
  raise exception 'room is private';end if;
 if exists(select 1 from public.room_members where room_id=p_room_id and user_id=caller)
 then return true;end if;
 if exists(select 1 from public.room_members where user_id=caller)
 then raise exception 'leave your current room first';end if;
 insert into public.room_members(room_id,user_id) values(p_room_id,caller);
 return true;
end;
$$;

create function public.phase2_room_leave(p_room_id uuid)
returns boolean
language plpgsql security definer set search_path=''
as $$
declare caller uuid; owner uuid;
begin
 caller:=auth.uid();
 if caller is null then raise exception 'not authenticated';end if;
 if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=caller)
 then return false;end if;
 select owner_id into owner from public.rooms where id=p_room_id for update;
 if owner=caller then
  -- Ending the owned room removes its current membership and chat snapshots.
  delete from public.rooms where id=p_room_id;
 else
  delete from public.room_members where room_id=p_room_id and user_id=caller;
 end if;
 return true;
end;
$$;

create function public.phase2_room_take_seat(p_room_id uuid,p_seat integer default null)
returns integer
language plpgsql security definer set search_path=''
as $$
declare caller uuid;
begin
 caller:=auth.uid();
 if caller is null then raise exception 'not authenticated';end if;
 if p_seat is not null and (p_seat<1 or p_seat>15)
 then raise exception 'invalid seat';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_room_id::text,0));
 if not exists(select 1 from public.room_members
   where room_id=p_room_id and user_id=caller for update)
 then raise exception 'join room first';end if;
 if p_seat is not null and exists(
    select 1 from public.room_members
    where room_id=p_room_id and seat_no=p_seat and user_id<>caller
 )then raise exception 'seat is occupied';end if;
 update public.room_members set seat_no=p_seat,is_muted=true
 where room_id=p_room_id and user_id=caller;
 return p_seat;
end;
$$;

create function public.phase2_room_members(p_room_id uuid)
returns table(user_id uuid,display_name text,seat_no integer,is_muted boolean)
language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not exists(select 1 from public.room_members m
      where m.room_id=p_room_id and m.user_id=auth.uid())
 then raise exception 'not a member';end if;
 return query select m.user_id,coalesce(p.display_name,'مستخدم جديد'),
  m.seat_no,m.is_muted from public.room_members m
 left join public.profiles p on p.id=m.user_id
 where m.room_id=p_room_id order by m.joined_at asc;
end;
$$;

create function public.phase2_room_send_message(p_room_id uuid,p_body text)
returns bigint
language plpgsql security definer set search_path=''
as $$
declare caller uuid; created_id bigint; safe_body text;
begin
 caller:=auth.uid();
 safe_body:=btrim(coalesce(p_body,''));
 if caller is null then raise exception 'not authenticated';end if;
 if char_length(safe_body) not between 1 and 500
 then raise exception 'message must be 1-500 characters';end if;
 if not exists(select 1 from public.room_members
  where room_id=p_room_id and user_id=caller)
 then raise exception 'join room first';end if;
 if exists(select 1 from public.room_messages where room_id=p_room_id
   and sender_id=caller and created_at>now()-interval '1 second')
 then raise exception 'slow down';end if;
 insert into public.room_messages(room_id,sender_id,body)
 values(p_room_id,caller,safe_body) returning id into created_id;
 return created_id;
end;
$$;

revoke all on function
 public.phase2_room_create(text,boolean),
 public.phase2_room_join(uuid),
 public.phase2_room_leave(uuid),
 public.phase2_room_take_seat(uuid,integer),
 public.phase2_room_members(uuid),
 public.phase2_room_send_message(uuid,text)
 from public,anon;
grant execute on function
 public.phase2_room_create(text,boolean),
 public.phase2_room_join(uuid),
 public.phase2_room_leave(uuid),
 public.phase2_room_take_seat(uuid,integer),
 public.phase2_room_members(uuid),
 public.phase2_room_send_message(uuid,text)
 to authenticated;

comment on table public.room_members is
 'Phase 2 room membership and server-locked 15 seat reservations only; voice transport not yet live.';
