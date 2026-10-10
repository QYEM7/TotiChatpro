-- Make signup display names authoritative at account creation, without trusting
-- client-supplied balances, IDs, roles, VIP levels or other metadata.
-- No existing user data are altered. Runs only in independent TotiChatpro.
create or replace function public.phase2_create_profile_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  safe_name text;
begin
  safe_name := left(btrim(coalesce(new.raw_user_meta_data->>'display_name', '')), 35);
  if char_length(safe_name) < 2 then
    safe_name := 'مستخدم جديد';
  end if;
  insert into public.profiles(id, display_name, bio)
  values(new.id, safe_name, '')
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.phase2_create_profile_from_auth()
  from public, anon, authenticated;
