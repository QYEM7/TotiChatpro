-- TotiChat Staging room customization; apply to isolated beta before enabling UI.
-- Preserves original room owner and 15-seat layout. Public images have strict size/mime and owner write policies.
alter table public.rooms
 add column if not exists welcome_message text not null default '' check(char_length(welcome_message)<=500),
 add column if not exists cover_path text,
 add column if not exists background_path text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('totichat-room-images','totichat-room-images',true,2097152,array['image/webp'])
 on conflict(id) do update set public=true,file_size_limit=2097152,allowed_mime_types=array['image/webp'];
create policy "totichat_room_images_read" on storage.objects
 for select to authenticated using(bucket_id='totichat-room-images');
create policy "totichat_room_images_add" on storage.objects
 for insert to authenticated with check(
  bucket_id='totichat-room-images' and
  split_part(name,'/',2) in('cover.webp','background.webp') and
  name=split_part(name,'/',1)||'/'||split_part(name,'/',2) and
  exists(select 1 from public.rooms r where r.id::text=split_part(name,'/',1) and r.owner_id=(select auth.uid()))
 );
create policy "totichat_room_images_update" on storage.objects
 for update to authenticated
 using(bucket_id='totichat-room-images' and exists(
  select 1 from public.rooms r where r.id::text=split_part(name,'/',1) and r.owner_id=(select auth.uid())
 ))
 with check(bucket_id='totichat-room-images' and
  split_part(name,'/',2) in('cover.webp','background.webp') and
  name=split_part(name,'/',1)||'/'||split_part(name,'/',2) and
  exists(select 1 from public.rooms r where r.id::text=split_part(name,'/',1) and r.owner_id=(select auth.uid()))
 );
create policy "totichat_room_images_remove" on storage.objects
 for delete to authenticated using(bucket_id='totichat-room-images' and exists(
  select 1 from public.rooms r where r.id::text=split_part(name,'/',1) and r.owner_id=(select auth.uid())
 ));
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
  background_path=case when p_background_path is null then background_path else nullif(p_background_path,'') end
 where id=p_room_id and owner_id=u;
 return found;
end $$;
revoke all on function public.phase2_room_customize(uuid,text,text,text) from public,anon;
grant execute on function public.phase2_room_customize(uuid,text,text,text) to authenticated;
