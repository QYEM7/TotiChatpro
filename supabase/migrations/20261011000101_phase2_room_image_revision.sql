-- Refresh public cover/background only when the room owner updates imagery.
alter table public.rooms
 add column if not exists image_revision uuid not null default gen_random_uuid();
create or replace function public.phase2_room_customize(p_room_id uuid,p_welcome_message text default null,p_cover_path text default null,p_background_path text default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from public.rooms where id=p_room_id and owner_id=u)
  then raise exception 'Room owner required' using errcode='42501'; end if;
 if p_welcome_message is not null and char_length(p_welcome_message)>500 then raise exception 'Welcome too long'; end if;
 if p_cover_path is not null and p_cover_path<>'' and p_cover_path<>p_room_id::text||'/cover.webp'
  then raise exception 'Invalid cover path'; end if;
 if p_background_path is not null and p_background_path<>'' and p_background_path<>p_room_id::text||'/background.webp'
  then raise exception 'Invalid background path'; end if;
 if p_cover_path is not null and p_cover_path<>'' and not exists(
   select 1 from storage.objects where bucket_id='totichat-room-images' and name=p_cover_path
 ) then raise exception 'Room cover has not been uploaded'; end if;
 if p_background_path is not null and p_background_path<>'' and not exists(
   select 1 from storage.objects where bucket_id='totichat-room-images' and name=p_background_path
 ) then raise exception 'Room background has not been uploaded'; end if;
 update public.rooms set
  welcome_message=coalesce(p_welcome_message,welcome_message),
  cover_path=case when p_cover_path is null then cover_path else nullif(p_cover_path,'') end,
  background_path=case when p_background_path is null then background_path else nullif(p_background_path,'') end,
  image_revision=case when p_cover_path is not null or p_background_path is not null then gen_random_uuid() else image_revision end
 where id=p_room_id and owner_id=u;
 return found;
end $$;
revoke all on function public.phase2_room_customize(uuid,text,text,text) from public,anon;
grant execute on function public.phase2_room_customize(uuid,text,text,text) to authenticated;
