
-- TotiChat: staging-only persistent support tickets. No wallet / agency mutation.
create table public.support_tickets(
 id uuid primary key default gen_random_uuid(),
 creator_id uuid not null references auth.users(id),
 category text not null check(category in('general','technical','account','recharge','host_agency','host_transfer')),
 subject text not null check(char_length(btrim(subject)) between 5 and 120),
 status text not null default 'open' check(status in('open','in_progress','waiting_user','resolved','closed')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 handled_by uuid references auth.users(id)
);
create index tc_support_tickets_creator on public.support_tickets(creator_id,updated_at desc);
create index tc_support_tickets_inbox on public.support_tickets(updated_at desc,id);
create index tc_support_tickets_handled on public.support_tickets(handled_by) where handled_by is not null;
create table public.support_messages(
 id bigint generated always as identity primary key,
 ticket_id uuid not null references public.support_tickets(id),
 author_id uuid not null references auth.users(id),
 body text not null check(char_length(btrim(body)) between 2 and 2500),
 created_at timestamptz not null default now()
);
create index tc_support_messages_thread on public.support_messages(ticket_id,id desc);
create index tc_support_messages_author on public.support_messages(author_id);
create table phase3.support_staff(user_id uuid primary key references auth.users(id),
 enabled boolean not null default true,assigned_by uuid references auth.users(id),
 updated_at timestamptz not null default now());
create index tc_support_staff_by on phase3.support_staff(assigned_by);
create table phase3.support_requests(actor_id uuid not null references auth.users(id),
 request_id uuid not null,payload jsonb not null,result jsonb not null,
 created_at timestamptz not null default now(),primary key(actor_id,request_id));
alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;
alter table phase3.support_staff enable row level security;
alter table phase3.support_requests enable row level security;
revoke all on public.support_tickets,public.support_messages,phase3.support_staff,phase3.support_requests from public,anon,authenticated;
-- Every exposed entrypoint requires a verified, non-expired session.
create function phase3.support_handler() returns boolean language sql security definer set search_path='' as $$
 select phase3.is_owner() or exists(select 1 from phase3.support_staff where user_id=auth.uid() and enabled)
$$;
revoke all on function phase3.support_handler() from public,anon;
grant execute on function phase3.support_handler() to authenticated;

create function phase3.support_list(p_scope text default 'mine',p_offset integer default 0,p_limit integer default 20)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); can_handle boolean:=phase3.support_handler(); total bigint; rows jsonb;
begin
 if p_scope not in('mine','all') or p_offset not between 0 and 50000 or p_limit not between 1 and 50 then raise exception 'Invalid page';end if;
 if p_scope='all' and not can_handle then raise exception 'Forbidden' using errcode='42501';end if;
 select count(*) into total from public.support_tickets t where p_scope='all' or t.creator_id=u;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into rows from(
 select id,creator_id,category,subject,status,updated_at,created_at from public.support_tickets t
 where p_scope='all' or t.creator_id=u order by updated_at desc,id desc offset p_offset limit p_limit
 ) q;
 return jsonb_build_object('rows',rows,'total',total,'canHandle',can_handle);
end $$;
create function phase3.support_thread_page(p_ticket_id uuid,p_offset integer default 0,p_limit integer default 30)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); t public.support_tickets%rowtype; total bigint; rows jsonb; can_handle boolean:=phase3.support_handler();
begin
 if p_ticket_id is null or p_offset not between 0 and 50000 or p_limit not between 1 and 50 then raise exception 'Invalid page';end if;
 select * into t from public.support_tickets where id=p_ticket_id;
 if not found or (t.creator_id<>u and not can_handle) then raise exception 'Ticket unavailable' using errcode='42501';end if;
 select count(*) into total from public.support_messages where ticket_id=p_ticket_id;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into rows from(
 select id,author_id,body,created_at from public.support_messages where ticket_id=p_ticket_id order by id desc offset p_offset limit p_limit
 ) q;
 return jsonb_build_object('ticket',to_jsonb(t),'messages',rows,'total',total,'canHandle',can_handle);
end $$;
create function phase3.support_staff_list(p_offset integer default 0,p_limit integer default 50)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); total bigint; rows jsonb;
begin
 if not phase3.is_owner() then raise exception 'Owner only' using errcode='42501';end if;
 if p_offset not between 0 and 50000 or p_limit not between 1 and 50 then raise exception 'Invalid page';end if;
 select count(*) into total from phase3.support_staff;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into rows from(
 select user_id,enabled,updated_at from phase3.support_staff order by updated_at desc offset p_offset limit p_limit
 ) q;
 return jsonb_build_object('rows',rows,'total',total);
end $$;
create function phase3.support_action(p_action text,p_data jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); prev phase3.support_requests%rowtype;
 payload jsonb; answer jsonb; t public.support_tickets%rowtype; target_id uuid;
 name text; content text; cat text;
begin
 if p_action not in('create','reply','status','staff_grant','staff_revoke') or p_request_id is null or
 p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>8500 then raise exception 'Invalid support action';end if;
 payload:=jsonb_build_object('action',p_action,'data',p_data);
 select * into prev from phase3.support_requests where actor_id=u and request_id=p_request_id;
 if found then
  if prev.payload<>payload then raise exception 'Request key conflict';end if;
  return prev.result;
 end if;
 if (select count(*) from phase3.support_requests where actor_id=u and created_at>now()-interval '1 minute')>=15 then raise exception 'Rate limit';end if;
 if p_action='create' then
  cat:=p_data->>'category';name:=btrim(coalesce(p_data->>'subject',''));content:=btrim(coalesce(p_data->>'message',''));
  if cat not in('general','technical','account','recharge','host_agency','host_transfer') or
   char_length(name) not between 5 and 120 or char_length(content) not between 2 and 2500 then raise exception 'Invalid ticket';end if;
  insert into public.support_tickets(creator_id,category,subject) values(u,cat,name) returning id into target_id;
  insert into public.support_messages(ticket_id,author_id,body) values(target_id,u,content);
 elsif p_action in('reply','status') then
  target_id:=(p_data->>'ticket_id')::uuid;
  select * into t from public.support_tickets where id=target_id for update;
  if not found or (t.creator_id<>u and not phase3.support_handler()) then raise exception 'Ticket unavailable' using errcode='42501';end if;
  if p_action='reply' then
   content:=btrim(coalesce(p_data->>'message',''));
   if t.status='closed' or char_length(content) not between 2 and 2500 then raise exception 'Cannot reply';end if;
   insert into public.support_messages(ticket_id,author_id,body) values(target_id,u,content);
   update public.support_tickets set updated_at=now(),status=case when t.creator_id=u then 'open' else 'waiting_user' end,
    handled_by=case when t.creator_id=u then handled_by else u end where id=target_id;
  else
   if not phase3.support_handler() then raise exception 'Forbidden' using errcode='42501';end if;
   name:=p_data->>'status';
   if name not in('open','in_progress','resolved','closed') then raise exception 'Invalid status';end if;
   update public.support_tickets set status=name,updated_at=now(),handled_by=u where id=target_id;
  end if;
 else
  if not phase3.is_owner() then raise exception 'Owner only' using errcode='42501';end if;
  target_id:=(p_data->>'user_id')::uuid;
  if target_id is null or target_id=u or not exists(select 1 from auth.users where id=target_id and email_confirmed_at is not null and deleted_at is null) then raise exception 'Invalid support staff';end if;
  insert into phase3.support_staff(user_id,enabled,assigned_by) values(target_id,p_action='staff_grant',u)
   on conflict(user_id) do update set enabled=excluded.enabled,assigned_by=u,updated_at=now();
  insert into public.security_audit(actor_id,action,details) values(u,'support_'||p_action,jsonb_build_object('user',target_id));
 end if;
 answer:=jsonb_build_object('id',target_id,'action',p_action,'status','completed');
 insert into phase3.support_requests(actor_id,request_id,payload,result) values(u,p_request_id,payload,answer);
 return answer;
end $$;
revoke all on function phase3.support_list(text,integer,integer),phase3.support_thread_page(uuid,integer,integer),
 phase3.support_staff_list(integer,integer),phase3.support_action(text,jsonb,uuid) from public,anon;
grant execute on function phase3.support_list(text,integer,integer),phase3.support_thread_page(uuid,integer,integer),
 phase3.support_staff_list(integer,integer),phase3.support_action(text,jsonb,uuid) to authenticated;
create function public.phase5_support_list(p_scope text default 'mine',p_offset integer default 0,p_limit integer default 20)
 returns jsonb language sql security invoker set search_path='' as $$select phase3.support_list(p_scope,p_offset,p_limit)$$;
create function public.phase5_support_thread_page(p_ticket_id uuid,p_offset integer default 0,p_limit integer default 30)
 returns jsonb language sql security invoker set search_path='' as $$select phase3.support_thread_page(p_ticket_id,p_offset,p_limit)$$;
create function public.phase5_support_staff_list(p_offset integer default 0,p_limit integer default 50)
 returns jsonb language sql security invoker set search_path='' as $$select phase3.support_staff_list(p_offset,p_limit)$$;
create function public.phase5_support_action(p_action text,p_data jsonb,p_request_id uuid)
 returns jsonb language sql security invoker set search_path='' as $$select phase3.support_action(p_action,p_data,p_request_id)$$;
revoke all on function public.phase5_support_list(text,integer,integer),public.phase5_support_thread_page(uuid,integer,integer),
 public.phase5_support_staff_list(integer,integer),public.phase5_support_action(text,jsonb,uuid) from public,anon;
grant execute on function public.phase5_support_list(text,integer,integer),public.phase5_support_thread_page(uuid,integer,integer),
 public.phase5_support_staff_list(integer,integer),public.phase5_support_action(text,jsonb,uuid) to authenticated;
