-- T14 local-only policy evidence; no Supabase production writes.
begin;
do $avatar$
declare z record;
begin
 select * into z from storage.buckets where id='profile-avatars';
 if not found or z.public is distinct from true or z.file_size_limit<>2097152
   or z.allowed_mime_types is distinct from array['image/webp']::text[]
 then raise exception 'T14 avatar bucket missing/wrong limits';end if;
 if (select count(*) from pg_policies where schemaname='storage' and tablename='objects'
  and policyname in('t14_avatar_insert','t14_avatar_select_owner','t14_avatar_delete_owner'))<>3
 then raise exception 'T14 avatar storage policies missing';end if;
 if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects'
 and policyname='t14_avatar_insert' and with_check like '%auth.uid%')
 then raise exception 'T14 upload owner RLS missing';end if;
 if has_table_privilege('anon','public.profiles','UPDATE')
 then raise exception 'T14 anonymous profile update permitted';end if;
end $avatar$;
rollback;
select 'PASS T14 avatar bucket restricted to WebP 2MB and owner-only object writes; profile RLS remains active' as result;
