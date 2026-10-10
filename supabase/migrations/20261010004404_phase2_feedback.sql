-- Authenticated, non-financial beta feedback and issue tracking.
-- Records are linked to signed-in users. No anonymous posts, no mock success.
create table public.beta_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('bug','idea','other')),
  message text not null check (char_length(btrim(message)) between 20 and 1500),
  app_version text not null default 'phase2-beta' check (char_length(app_version)<=40),
  created_at timestamptz not null default now()
);
create index beta_feedback_user_created
  on public.beta_feedback(user_id,created_at desc);
alter table public.beta_feedback enable row level security;
revoke all on public.beta_feedback from public,anon,authenticated;
grant select on public.beta_feedback to authenticated;
grant insert(user_id,category,message,app_version) on public.beta_feedback to authenticated;
create policy "Member reads own beta feedback"
on public.beta_feedback for select to authenticated
using (user_id=(select auth.uid()));
create policy "Member submits own beta feedback"
on public.beta_feedback for insert to authenticated
with check(user_id=(select auth.uid()));
comment on table public.beta_feedback is
 'Real beta user feedback with sender-scoped RLS. No fake submissions.';
