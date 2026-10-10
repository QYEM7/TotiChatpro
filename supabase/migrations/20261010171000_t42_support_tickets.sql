-- T42: private, authenticated customer-support tickets. Forward-only; no production data changes.
-- Never equate ticket handling with host/recharge agency approval or wallet authority.
create table phase3.support_staff(
 user_id uuid primary key references auth.users(id),
 enabled boolean not null default true,
 granted_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now()
);
create table phase3.support_tickets(
 id uuid primary key default gen_random_uuid(),
 creator_id uuid not null references auth.users(id),
 category text not null check(category in ('general','technical','account','recharge','host_agency','host_transfer')),
 subject text not null check(char_length(subject) between 5 and 120),
 status text not null default 'open' check(status in ('open','in_progress','waiting_user','resolved','closed')),
 assigned_to uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 first_staff_reply_at timestamptz,
 closed_at timestamptz
);
create table phase3.support_messages(
 id uuid primary key default gen_random_uuid(),
 ticket_id uuid not null references phase3.support_tickets(id) on delete restrict,
 author_id uuid not null references auth.users(id),
 body text not null check(char_length(body) between 2 and 2500),
 created_at timestamptz not null default now()
);
create table phase3.support_requests(
 actor_id uuid not null references auth.users(id),
 request_id uuid not null,
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index support_tickets_creator_updated on phase3.support_tickets(creator_id,updated_at desc);
create index support_tickets_status_updated on phase3.support_tickets(status,updated_at desc);
create index support_tickets_assigned_updated on phase3.support_tickets(assigned_to,updated_at desc);
create index support_messages_ticket_created on phase3.support_messages(ticket_id,created_at,id);
create index support_requests_created on phase3.support_requests(actor_id,created_at);
revoke all on phase3.support_staff,phase3.support_tickets,phase3.support_messages,phase3.support_requests from public,anon,authenticated;
alter table phase3.support_staff enable row level security;
alter table phase3.support_tickets enable row level security;
alter table phase3.support_messages enable row level security;
alter table phase3.support_requests enable row level security;

create function public.phase5_support_list(
 p_scope text default 'mine',p_offset integer default 0,p_limit integer default 30
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=phase3.actor(); is_owner boolean:=phase3.is_owner();
 staff boolean; total bigint; records jsonb;
begin
 staff:=is_owner or exists(select 1 from phase3.system_authority a where a.singleton and a.main_partner_id=u)
   or exists(select 1 from phase3.support_staff s where s.user_id=u and s.enabled);
 if p_scope is null or p_scope not in('mine','all') or
    (p_scope='all' and not staff) then
   raise exception 'Support scope denied' using errcode='42501';
 end if;
 if p_offset is null or p_offset<0 or p_offset>100000 or
    p_limit is null or p_limit<1 or p_limit>50 then
   raise exception 'Invalid support pagination';
 end if;
 select count(*) into total from phase3.support_tickets t
 where (p_scope='mine' and t.creator_id=u) or (p_scope='all' and staff);
 select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into records from(
   select id,creator_id,category,subject,status,assigned_to,created_at,updated_at,first_staff_reply_at,closed_at
   from phase3.support_tickets
   where (p_scope='mine' and creator_id=u) or (p_scope='all' and staff)
   order by updated_at desc,id desc limit p_limit offset p_offset
 )t;
 return jsonb_build_object('rows',records,'total',total,'offset',p_offset,
   'limit',p_limit,'canHandle',staff,'scope',p_scope);
end $fn$;

create function public.phase5_support_thread(p_ticket_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=phase3.actor();is_owner boolean:=phase3.is_owner();
 staff boolean; t phase3.support_tickets%rowtype; messages jsonb;
begin
 staff:=is_owner or exists(select 1 from phase3.system_authority a where a.singleton and a.main_partner_id=u)
   or exists(select 1 from phase3.support_staff s where s.user_id=u and s.enabled);
 if p_ticket_id is null then raise exception 'Ticket required';end if;
 select * into t from phase3.support_tickets where id=p_ticket_id;
 if not found or (t.creator_id<>u and not staff) then
   raise exception 'Ticket not found' using errcode='42501';
 end if;
 select coalesce(jsonb_agg(to_jsonb(m)),'[]'::jsonb) into messages from(
   select id,author_id,body,created_at from phase3.support_messages
   where ticket_id=t.id order by created_at,id limit 500
 )m;
 return jsonb_build_object('ticket',jsonb_build_object('id',t.id,'creator_id',t.creator_id,
  'category',t.category,'subject',t.subject,'status',t.status,'assigned_to',t.assigned_to,
  'created_at',t.created_at,'updated_at',t.updated_at),
  'messages',messages,'canHandle',staff);
end $fn$;

create function public.phase5_support_action(p_action text,p_data jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=phase3.actor();is_owner boolean:=phase3.is_owner();
 staff boolean; old phase3.support_requests%rowtype;
 payload jsonb;t phase3.support_tickets%rowtype;outcome jsonb;
 subject_text text; message_text text; note_status text; category_text text; target uuid;
begin
 if p_action is null or p_action not in('create','reply','status','staff_grant','staff_revoke')
    or p_data is null or jsonb_typeof(p_data)<>'object' or
    octet_length(p_data::text)>6500 or p_request_id is null then
   raise exception 'Invalid support action';
 end if;
 staff:=is_owner or exists(select 1 from phase3.system_authority a where a.singleton and a.main_partner_id=u)
   or exists(select 1 from phase3.support_staff s where s.user_id=u and s.enabled);
 payload:=jsonb_build_object('action',p_action,'data',p_data);
 select * into old from phase3.support_requests r
 where r.actor_id=u and r.request_id=p_request_id;
 if found then
   if old.payload<>payload then raise exception 'Idempotency key conflict';end if;
   return old.result;
 end if;
 if (select count(*) from phase3.support_requests r where r.actor_id=u
    and r.created_at>now()-interval '1 minute')>=20 then
   raise exception 'Support rate limit exceeded';
 end if;
 if p_action='create' then
   category_text:=p_data->>'category';subject_text:=btrim(p_data->>'subject');
   message_text:=btrim(p_data->>'message');
   if category_text is null or category_text not in ('general','technical','account','recharge','host_agency','host_transfer')
      or subject_text is null or char_length(subject_text) not between 5 and 120
      or message_text is null or char_length(message_text) not between 2 and 2500 then
     raise exception 'A category, subject and message are required';
   end if;
   if (select count(*) from phase3.support_tickets x where x.creator_id=u
       and x.status in('open','in_progress','waiting_user'))>=5 then
     raise exception 'Please resolve an open ticket before creating another';
   end if;
   insert into phase3.support_tickets(creator_id,category,subject)
   values(u,category_text,subject_text) returning * into t;
   insert into phase3.support_messages(ticket_id,author_id,body)
   values(t.id,u,message_text);
   outcome:=jsonb_build_object('id',t.id,'status',t.status);
 elsif p_action in('staff_grant','staff_revoke') then
   if not is_owner then raise exception 'Owner alone grants support access' using errcode='42501';end if;
   target:=(p_data->>'user_id')::uuid;
   if target is null or target=u or not exists(
     select 1 from auth.users au where au.id=target and au.email_confirmed_at is not null
     and au.deleted_at is null and (au.banned_until is null or au.banned_until<now())
   ) then raise exception 'Verified distinct staff user required';end if;
   insert into phase3.support_staff(user_id,enabled,granted_by)
   values(target,p_action='staff_grant',u)
   on conflict(user_id) do update set enabled=excluded.enabled,
     granted_by=excluded.granted_by,updated_at=now();
   outcome:=jsonb_build_object('id',target,'enabled',p_action='staff_grant');
 else
   if p_data->>'ticket_id' is null then raise exception 'Ticket ID required';end if;
   select * into t from phase3.support_tickets where id=(p_data->>'ticket_id')::uuid for update;
   if not found or (t.creator_id<>u and not staff) then
     raise exception 'Ticket not found' using errcode='42501';
   end if;
   if p_action='reply' then
     if t.status='closed' then raise exception 'Closed ticket cannot receive replies';end if;
     message_text:=btrim(p_data->>'message');
     if message_text is null or char_length(message_text) not between 2 and 2500 then
       raise exception 'Message must be 2 to 2500 characters';
     end if;
     insert into phase3.support_messages(ticket_id,author_id,body) values(t.id,u,message_text);
     update phase3.support_tickets
       set status=case when staff and u<>creator_id then 'waiting_user' else 'open' end,
           first_staff_reply_at=case when staff and u<>creator_id then coalesce(first_staff_reply_at,now()) else first_staff_reply_at end,
           assigned_to=case when staff and u<>creator_id then u else assigned_to end,
           updated_at=now()
       where id=t.id returning * into t;
   else
     if not staff then raise exception 'Support staff required' using errcode='42501';end if;
     note_status:=p_data->>'status';
     if note_status is null or note_status not in ('open','in_progress','resolved','closed') then
       raise exception 'Invalid ticket status';
     end if;
     update phase3.support_tickets
       set status=note_status,closed_at=case when note_status='closed' then now() else null end,
           updated_at=now()
       where id=t.id returning * into t;
   end if;
   outcome:=jsonb_build_object('id',t.id,'status',t.status);
 end if;
 insert into phase3.support_requests(actor_id,request_id,payload,result)
 values(u,p_request_id,payload,outcome);
 insert into public.security_audit(actor_id,action,details)
 values(u,'support_'||p_action,jsonb_build_object('id',outcome->>'id','request_id',p_request_id));
 return outcome;
end $fn$;
revoke all on function public.phase5_support_list(text,integer,integer),
 public.phase5_support_thread(uuid),public.phase5_support_action(text,jsonb,uuid)
 from public,anon,authenticated;
grant execute on function public.phase5_support_list(text,integer,integer),
 public.phase5_support_thread(uuid),public.phase5_support_action(text,jsonb,uuid)
 to authenticated;
comment on function public.phase5_support_action(text,jsonb,uuid) is
 'T42 support requests only: never approves agencies, transfers diamonds or changes balances.';
