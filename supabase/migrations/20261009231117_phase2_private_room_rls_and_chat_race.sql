-- Private-room members must be able to load the room they joined using
-- a one-time invite. Non-members still cannot enumerate private rooms.
drop policy "Only authenticated users see public or owned rooms" on public.rooms;
create policy "Authenticated users see public, owned or joined rooms"
on public.rooms for select to authenticated
using (
  not is_private
  or owner_id=(select auth.uid())
  or exists (
    select 1 from public.room_members m
    where m.room_id=rooms.id and m.user_id=(select auth.uid())
  )
);

-- Serialize sends by same account in the same room: concurrent requests must
-- not bypass the 1-second rate limit by both observing an empty history.
create or replace function public.phase2_room_send_message(p_room_id uuid,p_body text)
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
 perform pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended(caller::text||'|'||p_room_id::text,0)
 );
 if exists(select 1 from public.room_messages where room_id=p_room_id
   and sender_id=caller and created_at>now()-interval '1 second')
 then raise exception 'slow down';end if;
 insert into public.room_messages(room_id,sender_id,body)
 values(p_room_id,caller,safe_body) returning id into created_id;
 return created_id;
end;
$$;
revoke all on function public.phase2_room_send_message(uuid,text) from public,anon;
grant execute on function public.phase2_room_send_message(uuid,text) to authenticated;
