-- Signed-in room member controls own mic status only.
create function public.phase2_room_set_muted(p_room_id uuid,p_muted boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare uid uuid; seat integer;
begin
 uid:=auth.uid();
 if uid is null then raise exception 'authentication required'; end if;
 select seat_no into seat from public.room_members
 where room_id=p_room_id and user_id=uid for update;
 if not found then raise exception 'join the room first'; end if;
 if p_muted is not true and seat is null then raise exception 'take a seat first'; end if;
 update public.room_members set is_muted=coalesce(p_muted,true)
 where room_id=p_room_id and user_id=uid;
 return coalesce(p_muted,true);
end; $$;
revoke all on function public.phase2_room_set_muted(uuid,boolean) from public,anon;
grant execute on function public.phase2_room_set_muted(uuid,boolean) to authenticated;