-- T14 forward-only: pending local schema only. Public avatars by user choice.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-avatars','profile-avatars',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy t14_avatar_insert on storage.objects for insert to authenticated
with check(bucket_id='profile-avatars'
 and split_part(name,'/',1)=(select auth.uid())::text
 and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$');
create policy t14_avatar_delete on storage.objects for delete to authenticated
using(bucket_id='profile-avatars' and split_part(name,'/',1)=(select auth.uid())::text);
-- Refuse migration if existing external URL values would be invalidated.
do $$begin
 if exists(select 1 from public.profiles where avatar_url is not null and
  avatar_url !~ '^storage:profile-avatars/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$')
 then raise exception 'T14: preexisting profile URLs require migration review'; end if;
end $$;
alter table public.profiles drop constraint profiles_avatar_https_only;
alter table public.profiles add constraint t14_avatar_canonical_owner check(
 avatar_url is null or (length(avatar_url)<=160 and
 avatar_url ~ '^storage:profile-avatars/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' and
 split_part(avatar_url,'/',2)=id::text));
