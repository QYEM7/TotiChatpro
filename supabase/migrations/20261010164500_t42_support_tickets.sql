-- T42 real customer-support intake, separate from Owner-only host agency management.
create table phase3.support_agents(
 user_id uuid primary key references auth.users(id) on delete cascade,
 assigned_by uuid not null references auth.users(id),active boolean not null default true
);
alter table phase3.support_agents enable row level security;
revoke all on phase3.support_agents from public,anon,authenticated;
create table public.support_tickets(
 id uuid primary key default gen_random_uuid(),
 requester_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null,
 category text not null check(category in('general','host_agency_application','host_transfer_appeal','abuse_report')),
 title text not null check(length(btrim(title)) between 3 and 100),
 body text not null check(length(btrim(body)) between 10 and 2000),
 details jsonb not null default '{}'::jsonb check(jsonb_typeof(details)='object' and octet_length(details::text)<=1600),
 status text not null default 'submitted' check(status in('submitted','in_review','needs_information','resolved')),
 review_note text check(length(review_note)<=1000),
 reviewed_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(requester_id,request_id)
);
create index t42_support_owner on public.support_tickets(requester_id,created_at desc);
create index t42_support_pending on public.support_tickets(status,created_at desc);
alter table public.support_tickets enable row level security;
revoke all on public.support_tickets from public,anon,authenticated;
grant select on public.support_tickets to authenticated;
create policy t42_owner_read on public.support_tickets for select to authenticated using(requester_id=(select auth.uid()));
create function phase3.can_support_review() returns boolean
 language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();
begin
 return phase3.is_owner()
 or coalesce((select main_partner_id=u from phase3.system_authority where singleton),false)
 or exists(select 1 from phase3.support_agents where user_id=u and active);
end $$;
create function public.phase5_support_create(p_category text,p_title text,p_body text,
 p_details jsonb,p_request_id uuid) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();ticket public.support_tickets%rowtype;
begin
 if p_request_id is null or p_category is null or p_category not in
 ('general','host_agency_application','host_transfer_appeal','abuse_report')
 or p_title is null or length(btrim(p_title)) not between 3 and 100
 or p_body is null or length(btrim(p_body)) not between 10 and 2000
 or p_details is null or jsonb_typeof(p_details)<>'object'
 or octet_length(p_details::text)>1600 then raise exception 'Invalid support ticket';end if;
 if p_category='host_agency_application' and
 (coalesce(length(btrim(p_details->>'agency_name')),0) not between 2 and 80
 or coalesce(length(btrim(p_details->>'contact')),0)<3)
 then raise exception 'Agency name and contact required';end if;
 select * into ticket from public.support_tickets where requester_id=u and request_id=p_request_id;
 if found then
  if ticket.category<>p_category or ticket.title<>btrim(p_title)
   or ticket.body<>btrim(p_body) or ticket.details<>p_details
  then raise exception 'Idempotency key reused with changed content';end if;
  return to_jsonb(ticket);
 end if;
 if (select count(*) from public.support_tickets where requester_id=u
 and created_at>now()-interval '1 hour')>=5 then raise exception 'Ticket rate limit exceeded';end if;
 insert into public.support_tickets(requester_id,request_id,category,title,body,details)
 values(u,p_request_id,p_category,btrim(p_title),btrim(p_body),p_details)
 returning * into ticket;
 return to_jsonb(ticket);
end $$;
create function public.phase5_support_queue(p_offset integer default 0,p_limit integer default 40)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare tickets jsonb;
begin
 if not phase3.can_support_review() then raise exception 'Support permission required' using errcode='42501';end if;
 if p_offset is null or p_offset<0 or p_offset>100000
 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid pagination';end if;
 select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into tickets
 from (select id,requester_id,category,title,body,details,status,review_note,reviewed_by,created_at
 from public.support_tickets order by created_at desc,id limit p_limit offset p_offset) t;
 return tickets;
end $$;
create function public.phase5_support_review(p_id uuid,p_status text,p_note text)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();ticket public.support_tickets%rowtype;
begin
 if not phase3.can_support_review() then raise exception 'Support permission required' using errcode='42501';end if;
 if p_id is null or p_status not in('in_review','needs_information','resolved')
 or p_note is null or length(btrim(p_note)) not between 3 and 1000
 then raise exception 'Invalid review';end if;
 select * into ticket from public.support_tickets where id=p_id for update;
 if not found then raise exception 'Ticket not found';end if;
 if ticket.status='resolved' and p_status<>'resolved' then raise exception 'Cannot silently reopen resolved ticket';end if;
 update public.support_tickets set status=p_status,review_note=btrim(p_note),reviewed_by=u,
 updated_at=now() where id=p_id returning * into ticket;
 -- Reviewing a ticket DOES NOT approve/open any host or recharge agency.
 return to_jsonb(ticket);
end $$;
create function public.phase5_support_assign(p_user_id uuid,p_active boolean)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();
begin
 if not phase3.is_owner() then raise exception 'Owner only' using errcode='42501';end if;
 if p_user_id is null or p_user_id=u or p_active is null or not exists(
 select 1 from auth.users where id=p_user_id and email_confirmed_at is not null
 and deleted_at is null and (banned_until is null or banned_until<now()))
 then raise exception 'Verified support employee required';end if;
 insert into phase3.support_agents(user_id,assigned_by,active) values(p_user_id,u,p_active)
 on conflict(user_id) do update set assigned_by=u,active=excluded.active;
 insert into public.security_audit(actor_id,action,details)
 values(u,'support_agent_access',jsonb_build_object('user_id',p_user_id,'active',p_active));
 return jsonb_build_object('user_id',p_user_id,'active',p_active);
end $$;
revoke all on function phase3.can_support_review() from public,anon,authenticated;
revoke all on function public.phase5_support_create(text,text,text,jsonb,uuid),
 public.phase5_support_queue(integer,integer),
 public.phase5_support_review(uuid,text,text),
 public.phase5_support_assign(uuid,boolean) from public,anon,authenticated;
grant execute on function public.phase5_support_create(text,text,text,jsonb,uuid),
 public.phase5_support_queue(integer,integer),
 public.phase5_support_review(uuid,text,text),
 public.phase5_support_assign(uuid,boolean) to authenticated;
