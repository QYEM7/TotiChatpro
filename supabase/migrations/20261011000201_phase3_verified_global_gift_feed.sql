-- TotiChat Staging: verified worldwide gift announcements for ALL voice rooms.
-- Default OFF until a trusted administrator sets a real minimum price.
-- One row per actually completed, settled gift financial operation.
create table if not exists public.gift_announcement_settings(
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 min_gift_price bigint check(min_gift_price between 1 and 9007199254740991),
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id),
 constraint announcement_requires_threshold check(not enabled or min_gift_price is not null)
);
insert into public.gift_announcement_settings(singleton,enabled,min_gift_price)
 values(true,false,null) on conflict(singleton) do nothing;
alter table public.gift_announcement_settings enable row level security;
revoke all on public.gift_announcement_settings from public,anon,authenticated;

create table if not exists public.gift_global_announcements(
 id uuid primary key references public.gift_events(id),
 room_id uuid not null,
 sender_id uuid not null,
 recipient_id uuid not null,
 gift_id text not null,
 gift_name text not null,
 gift_icon text not null,
 sender_name text not null,
 recipient_name text not null,
 quantity integer not null check(quantity in(1,7,17,77,777)),
 unit_price bigint not null check(unit_price>0),
 total_coins bigint not null check(total_coins>0),
 created_at timestamptz not null
);
create index if not exists gift_global_announcements_recent on public.gift_global_announcements(created_at desc,id desc);
alter table public.gift_global_announcements enable row level security;
revoke all on public.gift_global_announcements from public,anon,authenticated;
grant select on public.gift_global_announcements to authenticated;
create policy gift_global_feed_all_signed_in_rooms on public.gift_global_announcements
 for select to authenticated using((select auth.uid()) is not null);

create or replace function public.phase3_gift_announce_verified()
returns trigger language plpgsql security definer set search_path='' as $$
declare cfg public.gift_announcement_settings%rowtype; g public.gift_catalog%rowtype;
 sname text; rname text;
begin
 -- Only the financial path creates gift_events, and that path must be fully settled.
 if not exists(select 1 from public.financial_operations op
  where op.id=new.id and op.operation='gift' and op.status='completed') then
  return new;
 end if;
 select * into cfg from public.gift_announcement_settings where singleton=true;
 if not found or not cfg.enabled or cfg.min_gift_price is null then return new;end if;
 select * into g from public.gift_catalog where id=new.gift_id;
 if not found or not g.global_announcement_enabled or g.price<cfg.min_gift_price then
  return new;
 end if;
 select display_name into sname from public.profiles where id=new.sender_id;
 select display_name into rname from public.profiles where id=new.recipient_id;
 insert into public.gift_global_announcements(
  id,room_id,sender_id,recipient_id,gift_id,gift_name,gift_icon,sender_name,
  recipient_name,quantity,unit_price,total_coins,created_at
 ) values(
  new.id,new.room_id,new.sender_id,new.recipient_id,new.gift_id,
  g.name,g.icon,coalesce(sname,'مستخدم'),coalesce(rname,'مستخدم'),
  new.quantity,g.price,new.amount,new.created_at
 ) on conflict(id) do nothing;
 return new;
end $$;
revoke all on function public.phase3_gift_announce_verified() from public,anon,authenticated;
drop trigger if exists tc_gift_announcement_after_payment on public.gift_events;
create trigger tc_gift_announcement_after_payment
 after insert on public.gift_events for each row
 execute function public.phase3_gift_announce_verified();

-- Permission comes from service_role only, not from a client-supplied "admin" flag.
-- The dashboard can call a backend-only administrative endpoint later.
create or replace function public.phase3_set_gift_global_threshold(
 p_enabled boolean,p_min_gift_price bigint
) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if p_enabled is null or (p_enabled and
  (p_min_gift_price is null or p_min_gift_price<1 or p_min_gift_price>9007199254740991)) then
  raise exception 'Invalid global announcement settings';
 end if;
 update public.gift_announcement_settings set
  enabled=p_enabled,
  min_gift_price=case when p_min_gift_price is null then min_gift_price else p_min_gift_price end,
  updated_at=now(),
  updated_by=auth.uid()
 where singleton=true;
 if not found then raise exception 'Announcement configuration unavailable';end if;
 return true;
end $$;
revoke all on function public.phase3_set_gift_global_threshold(boolean,bigint) from public,anon,authenticated;
grant execute on function public.phase3_set_gift_global_threshold(boolean,bigint) to service_role;

-- Global audience: all authenticated participants, regardless of current room_id.
do $$
begin
 if exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime')
 and not exists(select 1 from pg_catalog.pg_publication_tables
  where pubname='supabase_realtime' and schemaname='public'
  and tablename='gift_global_announcements') then
  alter publication supabase_realtime add table public.gift_global_announcements;
 end if;
end $$;
