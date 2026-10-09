-- 2026-10-09
-- TotiChatpro: production-safe public home banner catalog.
-- Apply only to the explicitly selected NEW Supabase backend.
-- Never add placeholder/fake advertisements or service_role tokens to browser assets.

create table if not exists public.home_banners (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 120),
  image_url text not null check (
    char_length(image_url) between 9 and 2048
    and image_url ~ '^https://[^[:space:]]+$'
  ),
  link_kind text not null default 'none'
    check (link_kind in ('none', 'screen', 'external')),
  link_target text,
  status text not null default 'draft'
    check (status in ('draft','published','archived')),
  sort_order integer not null default 100
    check (sort_order between 0 and 10000),
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint home_banners_valid_period check (
    starts_at is null or ends_at is null or starts_at < ends_at
  ),
  constraint home_banners_valid_link check (
    (link_kind = 'none' and link_target is null)
    or (link_kind = 'external' and link_target is not null and link_target ~ '^https://[^[:space:]]+$' and char_length(link_target) <= 2048)
    or (link_kind = 'screen' and link_target is not null and link_target in (
      'home','room','ranks','cp','agencyPreview','agency','storePreview',
      'vip','wallet','me','tour','profilePreview','rechargePreview','discoverPreview'
    ))
  )
);

create index if not exists home_banners_published_order_idx
on public.home_banners (sort_order, created_at desc)
where status = 'published';

alter table public.home_banners enable row level security;

-- Public clients can read only *currently published* ads.
-- Future/scheduled/draft/expired ads stay private.
drop policy if exists "Read active published home banners" on public.home_banners;
create policy "Read active published home banners"
  on public.home_banners
  for select to anon, authenticated
  using (
    status = 'published'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
  );

-- DO NOT grant direct ad-management writes to a mobile/web client.
-- Later: dashboard server-side API must check owner/staff permissions,
-- keep an audit trail, then write using a server-only service-role credential.
revoke all on table public.home_banners from public, anon, authenticated;
grant select on table public.home_banners to anon, authenticated;
grant all on table public.home_banners to service_role;

-- There is deliberately no seed data. New app displays "no ads" until
-- a properly authorized staff member creates and publishes a real ad.
