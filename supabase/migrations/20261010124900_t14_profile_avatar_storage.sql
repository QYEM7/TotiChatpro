-- T14. NEW unapplied migration: avatar storage without modifying profile schema.
-- Applies to TotiChatpro only after explicit deployment review. Local CI first.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('profile-avatars','profile-avatars',true,2097152,array['image/webp'])
on conflict(id) do nothing;

-- New immutable object per upload, no overwrite. Owner's own directory only.
create policy t14_avatar_insert
on storage.objects for insert to authenticated
with check (
 bucket_id='profile-avatars'
 and split_part(name,'/',1)=(select auth.uid())::text
 and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
 and owner_id=(select auth.uid())::text
);
-- Public bucket serves image bytes through its public URL. Owner SELECT is
-- scoped so user cannot list other users' object metadata using auth API.
create policy t14_avatar_select_owner
on storage.objects for select to authenticated
using (bucket_id='profile-avatars' and owner_id=(select auth.uid())::text);
create policy t14_avatar_delete_owner
on storage.objects for delete to authenticated
using (bucket_id='profile-avatars' and owner_id=(select auth.uid())::text);
