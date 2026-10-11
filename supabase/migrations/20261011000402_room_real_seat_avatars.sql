-- Genuine occupied-seat avatars, only visible to actual room members.
-- New RPC: preserves existing RPC consumers and never exposes private-room membership to outsiders.
create function phase3.room_members_visual(p_room_id uuid)
returns table(user_id uuid, display_name text, avatar_url text, seat_no integer, is_muted boolean)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_room_id is null or not exists (
   select 1 from public.room_members m where m.room_id=p_room_id and m.user_id=auth.uid()
 ) then raise exception 'Room membership required' using errcode='42501'; end if;
 return query
 select m.user_id,coalesce(p.display_name,'مستخدم جديد'),
    case when p.avatar_url like 'https://%.supabase.co/storage/v1/object/public/profile-avatars/%'
         then p.avatar_url else null end,
    m.seat_no,m.is_muted
 from public.room_members m left join public.profiles p on p.id=m.user_id
 where m.room_id=p_room_id order by m.joined_at asc;
end $$;
revoke all on function phase3.room_members_visual(uuid) from public,anon;
grant execute on function phase3.room_members_visual(uuid) to authenticated;
create function public.phase2_room_members_visual(p_room_id uuid)
returns table(user_id uuid,display_name text,avatar_url text,seat_no integer,is_muted boolean)
language plpgsql security invoker set search_path='' as $$
begin
 perform phase3.actor();
 return query select * from phase3.room_members_visual(p_room_id);
end $$;
revoke all on function public.phase2_room_members_visual(uuid) from public,anon;
grant execute on function public.phase2_room_members_visual(uuid) to authenticated;
