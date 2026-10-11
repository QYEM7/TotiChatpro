-- TotiChat Staging: verified text-only DMs.
-- Never store private audio; the live voice connection remains room-scoped.
create table if not exists public.direct_messages (
 id bigint generated always as identity primary key,
 sender_id uuid not null references auth.users(id),
 recipient_id uuid not null references auth.users(id),
 request_id uuid not null,
 body text not null check(char_length(btrim(body)) between 1 and 2000),
 created_at timestamptz not null default now(),
 read_at timestamptz,
 constraint dm_distinct_users check(sender_id<>recipient_id),
 constraint dm_request_unique unique(sender_id,request_id)
);
create index if not exists dm_sender_history on public.direct_messages(sender_id,created_at desc,id desc);
create index if not exists dm_recipient_history on public.direct_messages(recipient_id,created_at desc,id desc);
create index if not exists dm_unread_inbound on public.direct_messages(recipient_id,sender_id,id) where read_at is null;

create table if not exists public.dm_blocks (
 blocker_id uuid not null references auth.users(id),
 blocked_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 primary key(blocker_id,blocked_id),
 constraint dm_block_distinct_users check(blocker_id<>blocked_id)
);
create index if not exists dm_blocks_target on public.dm_blocks(blocked_id,blocker_id);

alter table public.direct_messages enable row level security;
alter table public.dm_blocks enable row level security;
revoke all on public.direct_messages from public,anon,authenticated;
revoke all on public.dm_blocks from public,anon,authenticated;
grant select on public.direct_messages to authenticated;
grant select on public.dm_blocks to authenticated;
create policy dm_two_participants_read on public.direct_messages for select to authenticated
 using ((select auth.uid())=sender_id or (select auth.uid())=recipient_id);
create policy dm_owner_blocks_read on public.dm_blocks for select to authenticated
 using ((select auth.uid())=blocker_id);

create or replace function public.phase2_dm_send(p_recipient_id uuid,p_body text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare sender uuid:=auth.uid(); safe_body text:=btrim(coalesce(p_body,'')); prior public.direct_messages%rowtype;
 new_id bigint;
begin
 if sender is null then raise exception 'Sign in required' using errcode='42501';end if;
 if p_request_id is null or p_recipient_id is null or p_recipient_id=sender or
    char_length(safe_body) not between 1 and 2000 then
   raise exception 'Invalid text message';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('tc-dm|'||sender::text,0));
 select * into prior from public.direct_messages where sender_id=sender and request_id=p_request_id;
 if found then
  if prior.recipient_id<>p_recipient_id or prior.body<>safe_body then
   raise exception 'Message request conflict';end if;
  return jsonb_build_object('id',prior.id,'sent',true,'replayed',true,'created_at',prior.created_at);
 end if;
 if not exists(select 1 from public.profiles p where p.id=p_recipient_id) then
   raise exception 'Recipient unavailable';end if;
 if exists(select 1 from public.dm_blocks b where
   (b.blocker_id=sender and b.blocked_id=p_recipient_id)
   or (b.blocker_id=p_recipient_id and b.blocked_id=sender)) then
   raise exception 'Messaging not permitted' using errcode='42501';end if;
 if (select count(*) from public.direct_messages
     where sender_id=sender and created_at>now()-interval '1 minute')>=20 then
   raise exception 'Too many messages; try again later';end if;
 if exists(select 1 from public.direct_messages
     where sender_id=sender and created_at>now()-interval '1 second') then
   raise exception 'Please slow down';end if;
 insert into public.direct_messages(sender_id,recipient_id,request_id,body)
 values(sender,p_recipient_id,p_request_id,safe_body) returning id into new_id;
 return jsonb_build_object('id',new_id,'sent',true,'replayed',false);
end $$;

create or replace function public.phase2_dm_thread(p_other_user uuid,p_before_id bigint default null,p_limit integer default 50)
returns table(id bigint,sender_id uuid,recipient_id uuid,body text,created_at timestamptz,read_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();
begin
 if caller is null then raise exception 'Sign in required' using errcode='42501';end if;
 if p_other_user is null or p_other_user=caller or p_limit not between 1 and 100 then
   raise exception 'Invalid conversation request';end if;
 return query select d.id,d.sender_id,d.recipient_id,d.body,d.created_at,d.read_at
 from public.direct_messages d
 where ((d.sender_id=caller and d.recipient_id=p_other_user)
  or (d.recipient_id=caller and d.sender_id=p_other_user))
  and (p_before_id is null or d.id<p_before_id)
 order by d.id desc limit p_limit;
end $$;

create or replace function public.phase2_dm_inbox(p_limit integer default 30)
returns table(other_user_id uuid,other_display_name text,last_id bigint,last_body text,
  last_at timestamptz,unread_count bigint)
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();
begin
 if caller is null then raise exception 'Sign in required' using errcode='42501';end if;
 if p_limit not between 1 and 100 then raise exception 'Invalid limit';end if;
 return query
 with contacts as (
  select distinct case when d.sender_id=caller then d.recipient_id else d.sender_id end as partner
  from public.direct_messages d where d.sender_id=caller or d.recipient_id=caller
 )
 select c.partner,p.display_name,l.id,l.body,l.created_at,
   (select count(*) from public.direct_messages u where u.sender_id=c.partner
    and u.recipient_id=caller and u.read_at is null) as unread_count
 from contacts c join lateral (
  select d.id,d.body,d.created_at from public.direct_messages d
  where (d.sender_id=caller and d.recipient_id=c.partner)
  or (d.sender_id=c.partner and d.recipient_id=caller)
  order by d.id desc limit 1
 ) l on true
 left join public.profiles p on p.id=c.partner
 order by l.id desc limit p_limit;
end $$;

create or replace function public.phase2_dm_mark_read(p_other_user uuid,p_through_id bigint default null)
returns integer language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid(); changed integer;
begin
 if caller is null then raise exception 'Sign in required' using errcode='42501';end if;
 if p_other_user is null or p_other_user=caller then raise exception 'Invalid sender';end if;
 update public.direct_messages set read_at=now()
 where recipient_id=caller and sender_id=p_other_user and read_at is null
 and (p_through_id is null or id<=p_through_id);
 get diagnostics changed=row_count;
 return changed;
end $$;

create or replace function public.phase2_dm_block(p_other_user uuid,p_block boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();
begin
 if caller is null then raise exception 'Sign in required' using errcode='42501';end if;
 if p_other_user is null or p_other_user=caller or p_block is null or
 not exists(select 1 from public.profiles where id=p_other_user) then
 raise exception 'Invalid block request';end if;
 if p_block then
   insert into public.dm_blocks(blocker_id,blocked_id) values(caller,p_other_user) on conflict do nothing;
 else
   delete from public.dm_blocks where blocker_id=caller and blocked_id=p_other_user;
 end if;
 return true;
end $$;

revoke all on function public.phase2_dm_send(uuid,text,uuid) from public,anon;
revoke all on function public.phase2_dm_thread(uuid,bigint,integer) from public,anon;
revoke all on function public.phase2_dm_inbox(integer) from public,anon;
revoke all on function public.phase2_dm_mark_read(uuid,bigint) from public,anon;
revoke all on function public.phase2_dm_block(uuid,boolean) from public,anon;
grant execute on function public.phase2_dm_send(uuid,text,uuid) to authenticated;
grant execute on function public.phase2_dm_thread(uuid,bigint,integer) to authenticated;
grant execute on function public.phase2_dm_inbox(integer) to authenticated;
grant execute on function public.phase2_dm_mark_read(uuid,bigint) to authenticated;
grant execute on function public.phase2_dm_block(uuid,boolean) to authenticated;

-- Postgres changes: only the two participants can read each message due to RLS.
do $$
begin
 if exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime')
 and not exists(select 1 from pg_catalog.pg_publication_tables
   where pubname='supabase_realtime' and schemaname='public' and tablename='direct_messages') then
  alter publication supabase_realtime add table public.direct_messages;
 end if;
end $$;
