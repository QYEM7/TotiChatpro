-- T23: static catalog invariants, hard bans on anonymous music access.
begin;
do $verify$
begin
 if (select count(*) from pg_class where oid in
 ('public.user_music_bookmarks'::regclass,'public.room_music_queue'::regclass)
 and relrowsecurity)<>2 then raise exception 'T23 music tables must both have RLS';end if;
 if has_table_privilege('anon','public.user_music_bookmarks','SELECT')
   or has_table_privilege('anon','public.room_music_queue','SELECT')
   or has_table_privilege('authenticated','public.user_music_bookmarks','UPDATE')
   or has_table_privilege('authenticated','public.room_music_queue','UPDATE')
 then raise exception 'T23 anonymous access or broad UPDATE grant';end if;
 if (select count(*) from pg_policies where schemaname='public' and policyname like 't23_%')<>6
 then raise exception 'T23 explicit RLS policies missing';end if;
end $verify$;
rollback;
select 'PASS T23: own-bookmark and room-member queue read RLS, owner write, anon blocked' as result;
