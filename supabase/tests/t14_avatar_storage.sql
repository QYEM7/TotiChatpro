begin;
do $t14$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(a,a::text||'@test.invalid',now(),false),(b,b::text||'@test.invalid',now(),false);
 update public.profiles set avatar_url='storage:profile-avatars/'||a||'/'||gen_random_uuid()||'.jpg' where id=a;
 if not exists(select 1 from public.profiles where id=a and avatar_url like 'storage:%') then raise exception 'T14 avatar path missing';end if;
 begin
  update public.profiles set avatar_url='storage:profile-avatars/'||b||'/'||gen_random_uuid()||'.jpg' where id=a;
  raise exception 'T14 accepted wrong owner path';
 exception when check_violation then null;end;
 if not exists(select 1 from storage.buckets where id='profile-avatars' and public and file_size_limit=5242880) then raise exception 'T14 bucket missing';end if;
 if (select count(*) from pg_policies where schemaname='storage' and policyname in('t14_avatar_insert','t14_avatar_delete'))<>2 then raise exception 'T14 bucket owner policies missing';end if;
end $t14$;
rollback;
select 'PASS T14: avatar bucket and per-owner profile path' as result;
