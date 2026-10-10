create table public.agencies (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references auth.users(id),
 kind text not null check(kind in('host','recharge')),name text not null check(char_length(name) between 2 and 80),
 commission_percent numeric(5,2) not null check(commission_percent between 0 and 100),
 is_active boolean not null default true,created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create unique index agencies_active_owner_kind_idx on public.agencies(owner_id,kind) where is_active;
create index agencies_creator_idx on public.agencies(created_by);
create table public.agency_registrations (
 id uuid primary key default gen_random_uuid(),applicant_id uuid not null references auth.users(id),
 kind text not null check(kind in('host','recharge')),name text not null check(char_length(name) between 2 and 80),
 details jsonb not null,status text not null default 'pending' check(status in('pending','approved','rejected')),
 agency_id uuid references public.agencies(id),reviewed_by uuid references auth.users(id),review_note text,
 created_at timestamptz not null default now(),reviewed_at timestamptz
);
create unique index agency_registration_pending_idx on public.agency_registrations(applicant_id,kind) where status='pending';
create index agency_registration_agency_idx on public.agency_registrations(agency_id);
create index agency_registration_reviewer_idx on public.agency_registrations(reviewed_by);
create table public.agency_members (
 user_id uuid primary key references auth.users(id),agency_id uuid not null references public.agencies(id),joined_at timestamptz not null default now()
);
create index agency_members_agency_idx on public.agency_members(agency_id);
create table public.agency_join_requests (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),agency_id uuid not null references public.agencies(id),old_agency_id uuid references public.agencies(id),
 status text not null check(status in('pending_old','pending_new','completed','rejected')),reason text not null check(char_length(reason) between 3 and 500),
 old_approved_by uuid references auth.users(id),accepted_by uuid references auth.users(id),review_note text,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create unique index agency_join_pending_idx on public.agency_join_requests(user_id) where status in('pending_old','pending_new');
create index agency_join_agency_idx on public.agency_join_requests(agency_id);
create index agency_join_old_agency_idx on public.agency_join_requests(old_agency_id);
create index agency_join_old_approver_idx on public.agency_join_requests(old_approved_by);
create index agency_join_acceptor_idx on public.agency_join_requests(accepted_by);
create table phase3.agency_requests(actor_id uuid references auth.users(id),request_id uuid,payload jsonb not null,result jsonb not null,created_at timestamptz not null default now(),primary key(actor_id,request_id));
alter table phase3.agency_requests enable row level security;
alter table public.agencies enable row level security;
alter table public.agency_registrations enable row level security;
alter table public.agency_members enable row level security;
alter table public.agency_join_requests enable row level security;
revoke all on phase3.agency_requests,public.agencies,public.agency_registrations,public.agency_members,public.agency_join_requests from public,anon,authenticated;
-- API state functions filter all private registration/member details server-side.
alter table public.gift_events add column agency_id uuid references public.agencies(id);
create index gift_events_agency_created_idx on public.gift_events(agency_id,created_at);
create function phase3.snapshot_gift_agency() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is distinct from new.sender_id then raise exception 'Gift actor mismatch' using errcode='42501';end if;
 select m.agency_id into new.agency_id from public.agency_members m join public.agencies a on a.id=m.agency_id where m.user_id=new.recipient_id and a.kind='host' and a.is_active;
 return new;
end $$;
revoke all on function phase3.snapshot_gift_agency() from public,anon,authenticated;
create trigger gift_agency_snapshot before insert on public.gift_events for each row execute function phase3.snapshot_gift_agency();
create function phase3.can_manage_agency(p_kind text) returns boolean language plpgsql security definer set search_path='' as $$
declare s jsonb:=phase3.admin_session();
begin return case p_kind when 'host' then (s->>'canManageHostAgencies')::boolean when 'recharge' then (s->>'canManageRechargeAgencies')::boolean else false end;end $$;
create function phase3.agency_action(p_action text,p_data jsonb,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
<<agency_action>>
declare u uuid:=phase3.actor();body jsonb;prior phase3.agency_requests%rowtype;reg public.agency_registrations%rowtype;a public.agencies%rowtype;j public.agency_join_requests%rowtype;kind text;name text;note text;commission numeric;old_id uuid;id uuid;answer jsonb;
begin
 if p_action is null or p_action not in('register','approve_registration','reject_registration','edit','close','join','approve_old','accept_join','reject_join','exception_transfer') or p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>5000 or p_request_id is null then raise exception 'Invalid agency operation';end if;
 body:=jsonb_build_object('action',p_action,'data',p_data);
 select * into prior from phase3.agency_requests where actor_id=u and request_id=p_request_id;
 if found then if prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;end if;
 if (select count(*) from phase3.agency_requests where actor_id=u and created_at>now()-interval '1 minute')>=30 then raise exception 'Rate limit exceeded';end if;
 if p_action='register' then
  kind:=p_data->>'kind';name:=btrim(p_data->>'name');
  if kind is null or kind not in('host','recharge') or name is null or char_length(name) not between 2 and 80 or coalesce(char_length(btrim(p_data->>'contact')),0) not between 3 and 100 or coalesce(char_length(btrim(p_data->>'reason')),0) not between 3 and 500 then raise exception 'Agency name, contact and reason required';end if;
  if exists(select 1 from public.agencies where owner_id=u and agencies.kind=agency_action.kind and is_active) then raise exception 'Agency already active';end if;
  insert into public.agency_registrations(applicant_id,kind,name,details) values(u,kind,name,jsonb_build_object('contact',p_data->>'contact','reason',p_data->>'reason')) returning * into reg;answer:=to_jsonb(reg);
 elsif p_action in('approve_registration','reject_registration') then
  select * into reg from public.agency_registrations where agency_registrations.id=(p_data->>'id')::uuid for update;
  if not found then raise exception 'Registration not found';end if;
  if not phase3.can_manage_agency(reg.kind) then raise exception 'Agency management permission required' using errcode='42501';end if;
  if reg.status<>'pending' then raise exception 'Registration already reviewed';end if;
  note:=btrim(p_data->>'note');if note is null or char_length(note) not between 3 and 500 then raise exception 'Review note required';end if;
  if p_action='approve_registration' then
   if not exists(select 1 from auth.users where auth.users.id=reg.applicant_id and email_confirmed_at is not null and deleted_at is null and (banned_until is null or banned_until<now())) then raise exception 'Verified active agency owner required';end if;
   commission:=(p_data->>'commission_percent')::numeric;if commission is null or commission<0 or commission>100 or commission='NaN'::numeric then raise exception 'Explicit valid commission required';end if;
   insert into public.agencies(owner_id,kind,name,commission_percent,created_by) values(reg.applicant_id,reg.kind,reg.name,commission,u) returning agencies.id into id;
  end if;
  update public.agency_registrations set status=case p_action when 'approve_registration' then 'approved' else 'rejected' end,agency_id=agency_action.id,reviewed_by=u,review_note=note,reviewed_at=now() where agency_registrations.id=reg.id returning * into reg;answer:=to_jsonb(reg);
 elsif p_action in('edit','close') then
  select * into a from public.agencies where agencies.id=(p_data->>'id')::uuid for update;
  if not found then raise exception 'Agency not found';end if;
  if not phase3.can_manage_agency(a.kind) then raise exception 'Agency management permission required' using errcode='42501';end if;
  if p_action='close' then
   note:=btrim(p_data->>'note');if note is null or char_length(note) not between 3 and 500 then raise exception 'Closure reason required';end if;
   update public.agencies set is_active=false,updated_at=now() where agencies.id=a.id returning * into a;
  else
   name:=btrim(p_data->>'name');commission:=(p_data->>'commission_percent')::numeric;
   if name is null or char_length(name) not between 2 and 80 or commission is null or commission<0 or commission>100 or commission='NaN'::numeric then raise exception 'Agency settings invalid';end if;
   update public.agencies set name=agency_action.name,commission_percent=commission,updated_at=now() where agencies.id=a.id returning * into a;
  end if;answer:=to_jsonb(a);
 elsif p_action='join' then
  select * into a from public.agencies where agencies.id=(p_data->>'agency_id')::uuid and is_active and agencies.kind='host' for share;
  if not found then raise exception 'Active host agency required';end if;
  perform user_id from public.wallets where user_id=u for update;
  select agency_id into old_id from public.agency_members where user_id=u;
  if old_id=a.id then raise exception 'Already a member';end if;
  note:=btrim(p_data->>'reason');if note is null or char_length(note) not between 3 and 500 then raise exception 'Join reason required';end if;
  insert into public.agency_join_requests(user_id,agency_id,old_agency_id,status,reason) values(u,a.id,old_id,case when old_id is null then 'pending_new' else 'pending_old' end,note) returning * into j;answer:=to_jsonb(j);
 else
  select * into j from public.agency_join_requests where agency_join_requests.id=(p_data->>'id')::uuid for update;
  if not found then raise exception 'Join request not found';end if;
  select * into a from public.agencies where agencies.id=j.agency_id for share;
  if p_action='approve_old' then
   if j.status<>'pending_old' or not exists(select 1 from public.agencies where agencies.id=j.old_agency_id and owner_id=u) then raise exception 'Old agency approval required' using errcode='42501';end if;
   update public.agency_join_requests set status='pending_new',old_approved_by=u,updated_at=now() where agency_join_requests.id=j.id returning * into j;
  elsif p_action='reject_join' then
   if j.status not in('pending_old','pending_new') or not(a.owner_id=u or exists(select 1 from public.agencies where agencies.id=j.old_agency_id and owner_id=u) or phase3.can_manage_agency('host')) then raise exception 'Agency approval permission required' using errcode='42501';end if;
   update public.agency_join_requests set status='rejected',accepted_by=u,updated_at=now() where agency_join_requests.id=j.id returning * into j;
  else
   if p_action='exception_transfer' then
    if j.status not in('pending_old','pending_new') or not phase3.can_manage_agency('host') then raise exception 'Investigating administrator required' using errcode='42501';end if;
    note:=btrim(p_data->>'note');if note is null or char_length(note) not between 10 and 500 then raise exception 'Investigation decision required';end if;
   elsif j.status<>'pending_new' or a.owner_id<>u then raise exception 'New agency approval required' using errcode='42501';end if;
   if not a.is_active or a.kind<>'host' then raise exception 'Target agency inactive';end if;
   if not exists(select 1 from auth.users where auth.users.id=j.user_id and deleted_at is null and email_confirmed_at is not null and (banned_until is null or banned_until<now())) then raise exception 'Active confirmed host required';end if;
   perform user_id from public.wallets where user_id=j.user_id for update;
   select agency_id into old_id from public.agency_members where user_id=j.user_id;
   if old_id is distinct from j.old_agency_id then raise exception 'Host membership changed; submit a new request';end if;
   insert into public.agency_members(user_id,agency_id) values(j.user_id,j.agency_id) on conflict(user_id) do update set agency_id=excluded.agency_id,joined_at=now();
   update public.agency_join_requests set status='completed',accepted_by=u,review_note=note,updated_at=now() where agency_join_requests.id=j.id returning * into j;
  end if;answer:=to_jsonb(j);
 end if;
 insert into phase3.agency_requests values(u,p_request_id,body,answer,now());
 insert into public.security_audit(actor_id,action,details) values(u,'agency_'||p_action,body||jsonb_build_object('result_id',answer->>'id'));
 return answer;
end $$;
create function phase3.agency_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();s jsonb:=phase3.admin_session();manage_host boolean:=(s->>'canManageHostAgencies')::boolean;manage_recharge boolean:=(s->>'canManageRechargeAgencies')::boolean;
begin return jsonb_build_object('authority',s,
 'agencies',(select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at),'[]') from public.agencies a where (a.kind='host' and a.is_active) or a.owner_id=u or (a.kind='host' and manage_host) or (a.kind='recharge' and manage_recharge)),
 'registrations',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]') from public.agency_registrations r where r.applicant_id=u or (r.kind='host' and manage_host) or (r.kind='recharge' and manage_recharge)),
 'members',(select coalesce(jsonb_agg(to_jsonb(m)),'[]') from public.agency_members m join public.agencies a on a.id=m.agency_id where m.user_id=u or a.owner_id=u or manage_host),
 'requests',(select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]') from public.agency_join_requests r where r.user_id=u or manage_host or exists(select 1 from public.agencies a where a.id in(r.agency_id,r.old_agency_id) and a.owner_id=u)));
end $$;
create function public.phase4_agency_action(p_action text,p_data jsonb,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select phase3.agency_action(p_action,p_data,p_request_id) $$;
create function public.phase4_agency_state() returns jsonb language sql security invoker set search_path='' as $$ select phase3.agency_state() $$;
revoke all on function phase3.can_manage_agency(text),phase3.agency_action(text,jsonb,uuid),phase3.agency_state(),public.phase4_agency_action(text,jsonb,uuid),public.phase4_agency_state() from public,anon,authenticated;
grant execute on function phase3.agency_action(text,jsonb,uuid),phase3.agency_state(),public.phase4_agency_action(text,jsonb,uuid),public.phase4_agency_state() to authenticated;
