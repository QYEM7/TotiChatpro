-- T17 pending migration: enable Postgres Changes for approved room tables.
-- All published tables already have scoped RLS and authenticated SELECT grants.
-- NEVER grant anon access to private rooms/messages/members.
do $$
declare t text;
begin
 if not exists(select 1 from pg_publication where pubname='supabase_realtime') then
  raise exception 'Supabase realtime publication missing; review environment';
 end if;
 foreach t in array array['rooms','room_members','room_messages'] loop
  if not exists(select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
    execute format('alter publication supabase_realtime add table public.%I',t);
  end if;
 end loop;
end $$;
