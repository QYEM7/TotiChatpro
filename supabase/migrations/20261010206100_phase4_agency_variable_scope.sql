create or replace function phase3.agency_action(p_action text,p_data jsonb,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
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
  update public.agency_registrations set status=case p_action when 'approve_registration' then 'approved' else 'rejected' end,agency_id=id,reviewed_by=u,review_note=note,reviewed_at=now() where agency_registrations.id=reg.id returning * into reg;answer:=to_jsonb(reg);
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
