-- Phase 2: real, initially zero wallet balances for new accounts.
-- No external top-ups, currency minting or demo credits are authorized here.
-- Clients have READ-ONLY grants. A later audited server-only ledger
-- transaction will be required before agents, gifts or diamonds are enabled.
create table public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  coins bigint not null default 0 check (coins >= 0),
  diamonds bigint not null default 0 check (diamonds >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.wallet_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  currency text not null check (currency in ('coins','diamonds')),
  amount_change bigint not null check (amount_change <> 0),
  balance_after bigint not null check (balance_after >= 0),
  operation_id uuid not null unique,
  kind text not null check (kind in (
    'owner_grant','agent_topup','gift_sent','gift_received',
    'store_purchase','diamond_conversion','monthly_settlement',
    'moderation_adjustment','refund'
  )),
  created_at timestamptz not null default now()
);
create index phase2_wallet_ledger_user_created
  on public.wallet_ledger(user_id,created_at desc);

alter table public.wallets enable row level security;
alter table public.wallet_ledger enable row level security;
revoke all on public.wallets,public.wallet_ledger from public,anon,authenticated;
grant select on public.wallets,public.wallet_ledger to authenticated;

create policy "Account can read own wallet balance only"
on public.wallets for select to authenticated
using (user_id=(select auth.uid()));

create policy "Account can read own financial journal only"
on public.wallet_ledger for select to authenticated
using (user_id=(select auth.uid()));

create function public.phase2_create_wallet_from_auth()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  insert into public.wallets(user_id) values(new.id)
  on conflict(user_id) do nothing;
  return new;
end;
$$;
revoke all on function public.phase2_create_wallet_from_auth()
  from public,anon,authenticated;
create trigger phase2_after_auth_wallet
after insert on auth.users
for each row execute function public.phase2_create_wallet_from_auth();

comment on table public.wallets is
  'Authoritative balances. New users start with zero; no client write access.';
comment on table public.wallet_ledger is
  'Immutable to browser users. Every future currency operation must be atomic, idempotent and audited server-side.';
