begin;
do $verify$
declare t text;
begin
 foreach t in array array['rooms','room_members','room_messages'] loop
   if not exists(select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
    raise exception 'T17 not published: %',t;end if;
   if not (select relrowsecurity from pg_class where oid=format('public.%I',t)::regclass)
    then raise exception 'T17 RLS disabled on %',t;end if;
 end loop;
 if has_table_privilege('anon','public.room_messages','SELECT') then
    raise exception 'T17 anon can read room messages';end if;
end $verify$;
rollback;
select 'PASS T17: RLS-protected rooms, room members and messages enabled for Realtime Postgres Changes' as result;
