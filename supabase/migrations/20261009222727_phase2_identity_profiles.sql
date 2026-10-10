-- TotiChatpro Phase 2: NEW isolated auth/profile foundation.
-- Applies ONLY to Supabase project sqedsnyvjblvbjbizcay.
-- No legacy account, wallet, room, roles or experimental data imported.
-- Keep existing published home_banners table and its RLS unchanged.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'مستخدم جديد',
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (char_length(btrim(display_name)) between 1 and 40),
  constraint profiles_bio_length check (char_length(bio) <= 160),
  constraint profiles_avatar_https_only check (
    avatar_url is null or (char_length(avatar_url) <= 600 and avatar_url ~ '^https://')
  )
);

alter table public.profiles enable row level security;

-- Clients may not insert arbitrary profiles, modify owner IDs/timestamps or delete rows.
revoke all on table public.profiles from public, anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (display_name, bio, avatar_url) on table public.profiles to authenticated;

create policy "Authenticated members read profiles"
  on public.profiles
  for select to authenticated
  using ((select auth.uid()) is not null);

create policy "A member updates only their own profile"
  on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create function public.phase2_create_profile_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, display_name, bio)
  values (new.id, 'مستخدم جديد', '')
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Trigger functions should not be callable as public RPCs.
revoke all on function public.phase2_create_profile_from_auth() from public, anon, authenticated;

create trigger phase2_after_auth_signup
after insert on auth.users
for each row execute function public.phase2_create_profile_from_auth();

create function public.phase2_touch_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.phase2_touch_profile_updated_at() from public, anon, authenticated;

create trigger phase2_profile_updated_at
before update on public.profiles
for each row execute function public.phase2_touch_profile_updated_at();

comment on table public.profiles is
  'TotiChatpro clean Phase 2 identity profiles; no legacy balances or experiments.';
