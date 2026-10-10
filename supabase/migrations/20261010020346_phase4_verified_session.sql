create or replace function phase3.actor() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from auth.users where id=u and deleted_at is null and email_confirmed_at is not null and not coalesce(is_anonymous,false) and (banned_until is null or banned_until<now())) then raise exception 'Verified account required' using errcode='42501';end if;
 if not exists(select 1 from auth.sessions where user_id=u and id=(auth.jwt()->>'session_id')::uuid) then raise exception 'Session expired' using errcode='42501';end if;
 if exists(select 1 from auth.mfa_factors where user_id=u and status='verified') and coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Two-factor verification required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));return u;
end $$;
create table phase3.session_audits(session_id uuid primary key references auth.sessions(id) on delete cascade,user_id uuid not null references auth.users(id),created_at timestamptz not null default now());
alter table phase3.session_audits enable row level security;
revoke all on phase3.session_audits from public,anon,authenticated;
create function phase3.verified_session() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();s uuid:=(auth.jwt()->>'session_id')::uuid;added uuid;
begin
 perform phase3.is_owner();
 insert into phase3.session_audits(session_id,user_id) values(s,u) on conflict do nothing returning session_id into added;
 if added is not null then insert into public.security_audit(actor_id,action,details) values(u,'session_verified',jsonb_build_object('session_id',s,'aal',auth.jwt()->>'aal'));end if;
 return u;
end $$;
create function public.phase4_verified_session() returns uuid language sql security invoker set search_path='' as $$ select phase3.verified_session() $$;
revoke all on function phase3.verified_session(),public.phase4_verified_session() from public,anon,authenticated;
grant execute on function phase3.verified_session(),public.phase4_verified_session() to authenticated;
