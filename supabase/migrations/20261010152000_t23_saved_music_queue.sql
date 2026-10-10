-- T23: account-owned saved music references and room queue metadata only.
-- Streaming and licensing intentionally NOT implemented. Forward-only, not deployed.
create table public.user_music_bookmarks (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(char_length(btrim(title)) between 2 and 100),
 artist text not null default '' check(char_length(artist)<=80),
 reference_url text check(reference_url is null or
   (length(reference_url)<=500 and reference_url ~ '^https://[^[:space:]]+$')),
 created_at timestamptz not null default now()
);
create index t23_saved_owner_created on public.user_music_bookmarks(owner_id,created_at desc);
alter table public.user_music_bookmarks enable row level security;
revoke all on public.user_music_bookmarks from public,anon,authenticated;
grant select,insert,delete on public.user_music_bookmarks to authenticated;
create policy t23_saved_read on public.user_music_bookmarks for select to authenticated
 using(owner_id=(select auth.uid()));
create policy t23_saved_add on public.user_music_bookmarks for insert to authenticated
 with check(owner_id=(select auth.uid()));
create policy t23_saved_remove on public.user_music_bookmarks for delete to authenticated
 using(owner_id=(select auth.uid()));
comment on table public.user_music_bookmarks is
 'Private user-owned track reference bookmarks only. No music playback authorization.';
create table public.room_music_queue (
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.rooms(id) on delete cascade,
 bookmark_id uuid references public.user_music_bookmarks(id) on delete set null,
 added_by uuid not null references auth.users(id) on delete cascade,
 title text not null check(char_length(btrim(title)) between 2 and 100),
 artist text not null default '' check(char_length(artist)<=80),
 created_at timestamptz not null default now(),
 unique(room_id,bookmark_id)
);
create index t23_queue_room_created on public.room_music_queue(room_id,created_at,id);
alter table public.room_music_queue enable row level security;
revoke all on public.room_music_queue from public,anon,authenticated;
grant select,insert,delete on public.room_music_queue to authenticated;
create policy t23_queue_members_read on public.room_music_queue for select to authenticated
 using(exists(select 1 from public.room_members m
   where m.room_id=room_music_queue.room_id and m.user_id=(select auth.uid())));
create policy t23_queue_owner_add on public.room_music_queue for insert to authenticated
 with check(added_by=(select auth.uid())
   and exists(select 1 from public.rooms r where r.id=room_id and r.owner_id=(select auth.uid()))
   and exists(select 1 from public.user_music_bookmarks b
      where b.id=bookmark_id and b.owner_id=(select auth.uid())
        and b.title=room_music_queue.title and b.artist=room_music_queue.artist));
create policy t23_queue_owner_remove on public.room_music_queue for delete to authenticated
 using(added_by=(select auth.uid()) and exists(
 select 1 from public.rooms r where r.id=room_id and r.owner_id=(select auth.uid())));
comment on table public.room_music_queue is
 'Room playlist metadata visible to members only; not audio, synchronized playback or payments.';
