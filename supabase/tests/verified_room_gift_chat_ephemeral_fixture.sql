-- Disposable CI PostgreSQL fixture ONLY; no Supabase project connection.
\set ON_ERROR_STOP on

create role anon nologin;
create role authenticated nologin;
create schema auth;
create schema phase3;

create table auth.users(id uuid primary key);
create table public.rooms(id uuid primary key);
create table public.profiles(
 id uuid primary key references auth.users(id),
 display_name text not null
);
create table public.gift_catalog(
 id text primary key,
 name text not null,
 icon text not null
);
create table public.financial_operations(
 id uuid primary key,
 operation text not null,
 status text not null
);
create table public.gift_events(
 id uuid primary key references public.financial_operations(id),
 sender_id uuid not null references auth.users(id),
 recipient_id uuid not null references auth.users(id),
 room_id uuid not null references public.rooms(id),
 gift_id text not null references public.gift_catalog(id),
 quantity integer not null,
 amount bigint not null
);
create table public.wallet_ledger(
 id bigint generated always as identity primary key,
 transaction_id uuid not null references public.financial_operations(id),
 user_id uuid not null references auth.users(id),
 kind text not null,
 currency text not null,
 amount_change bigint not null
);
create table public.room_messages(
 id bigint generated always as identity primary key,
 room_id uuid not null references public.rooms(id),
 sender_id uuid not null references auth.users(id),
 body text not null check(char_length(btrim(body)) between 1 and 500),
 created_at timestamptz not null default now()
);
alter table public.room_messages enable row level security;
revoke all on public.room_messages from public,anon,authenticated;
grant select on public.room_messages to authenticated;

insert into auth.users(id) values
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222');
insert into public.rooms(id) values
 ('33333333-3333-4333-8333-333333333333');
insert into public.profiles(id,display_name) values
 ('11111111-1111-4111-8111-111111111111','Sender'),
 ('22222222-2222-4222-8222-222222222222','Recipient');
insert into public.gift_catalog(id,name,icon) values
 ('rose','Rose','🌹');
insert into public.financial_operations(id,operation,status) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','gift','completed'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','gift','completed'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','gift','completed'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','gift','failed');
