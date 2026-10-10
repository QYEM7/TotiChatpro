create table public.cp_relationships (
 id uuid primary key default gen_random_uuid(),user_a uuid not null references auth.users(id),user_b uuid not null references auth.users(id),
 requested_by uuid not null references auth.users(id),type_id text not null references public.cp_types(id),
 accepted_at timestamptz,ended_at timestamptz,gift_gold bigint not null default 0 check(gift_gold>=0 and gift_gold<=9007199254740991),
 created_at timestamptz not null default now(),check(user_a<user_b),check(requested_by in(user_a,user_b))
);
create unique index cp_open_pair_idx on public.cp_relationships(user_a,user_b,type_id) where ended_at is null;
create index cp_relationship_b_idx on public.cp_relationships(user_b,created_at desc);
create index cp_relationship_type_idx on public.cp_relationships(type_id);
create index cp_relationship_requester_idx on public.cp_relationships(requested_by) where ended_at is null and accepted_at is null;
create table phase3.cp_slots (
 user_id uuid not null references auth.users(id),type_id text not null references public.cp_types(id),
 relationship_id uuid not null references public.cp_relationships(id),primary key(user_id,type_id)
);
create index cp_slots_relationship_idx on phase3.cp_slots(relationship_id);
create index cp_slots_type_idx on phase3.cp_slots(type_id);
create table phase3.cp_requests (
 actor_id uuid not null references auth.users(id),request_id uuid not null,payload jsonb not null,result jsonb not null,
 created_at timestamptz not null default now(),primary key(actor_id,request_id)
);
-- The legacy configuration has no cross-type conflicts. Keep its extension points empty.
create table phase3.cp_type_conflicts (type_a text references public.cp_types(id),type_b text references public.cp_types(id),primary key(type_a,type_b),check(type_a<type_b));
create table phase3.cp_pair_type_conflicts (type_a text references public.cp_types(id),type_b text references public.cp_types(id),primary key(type_a,type_b),check(type_a<type_b));
alter table public.cp_relationships enable row level security;
alter table phase3.cp_slots enable row level security;
alter table phase3.cp_requests enable row level security;
alter table phase3.cp_type_conflicts enable row level security;
alter table phase3.cp_pair_type_conflicts enable row level security;
revoke all on public.cp_relationships,phase3.cp_slots,phase3.cp_requests,phase3.cp_type_conflicts,phase3.cp_pair_type_conflicts from public,anon,authenticated;
grant select on public.cp_relationships to authenticated;
create policy cp_participant on public.cp_relationships for select to authenticated using((select auth.uid()) in(user_a,user_b));
alter table public.gift_events add column relationship_id uuid references public.cp_relationships(id);
create index gift_events_relationship_idx on public.gift_events(relationship_id);
create function phase3.assert_cp_gift(p_type text,p_recipient uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();relation uuid;
begin
 if p_type is null then return null;end if;
 if not exists(select 1 from public.cp_types where id=p_type and enabled) then raise exception 'CP type unavailable';end if;
 select r.id into relation from public.cp_relationships r
 join phase3.cp_slots a on a.relationship_id=r.id and a.user_id=r.user_a and a.type_id=r.type_id
 join phase3.cp_slots b on b.relationship_id=r.id and b.user_id=r.user_b and b.type_id=r.type_id
 where r.user_a=least(u,p_recipient) and r.user_b=greatest(u,p_recipient) and r.type_id=p_type and r.accepted_at is not null and r.accepted_at<=now() and r.ended_at is null for share of r;
 if relation is null then raise exception 'Active matching CP relationship required';end if;return relation;
end $$;
create function phase3.cp_action(p_partner_id uuid,p_type_id text,p_action text,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();relation public.cp_relationships%rowtype;body jsonb;answer jsonb;prior phase3.cp_requests%rowtype;label text;
begin
 if p_partner_id is null or p_partner_id=u or p_type_id is null or p_action is null or p_action not in('request','accept','reject','end') or p_request_id is null then raise exception 'Invalid CP action';end if;
 body:=jsonb_build_object('partner',p_partner_id,'type',p_type_id,'action',p_action);
 select * into prior from phase3.cp_requests where actor_id=u and request_id=p_request_id;
 if found then if prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;end if;
 if (select count(*) from phase3.cp_requests where actor_id=u and created_at>now()-interval '1 minute')>=30 then raise exception 'Rate limit exceeded';end if;
 if not exists(select 1 from public.profiles where id=p_partner_id) then raise exception 'Partner unavailable';end if;
 if p_action in('request','accept') then
  if not exists(select 1 from auth.users where id=p_partner_id and email_confirmed_at is not null and not coalesce(is_anonymous,false) and (banned_until is null or banned_until<now())) then raise exception 'Verified active partner required';end if;
  select t.label into label from public.cp_types t where id=p_type_id and enabled for share;
  if label is null then raise exception 'CP type unavailable';end if;
 end if;
 -- Same ordered wallet locks as gifts. CP checks run after these locks.
 perform user_id from public.wallets where user_id in(u,p_partner_id) order by user_id for update;
 select * into relation from public.cp_relationships where user_a=least(u,p_partner_id) and user_b=greatest(u,p_partner_id) and type_id=p_type_id and ended_at is null for update;
 if p_action='request' then
  if relation.id is null then
   if exists(select 1 from phase3.cp_slots where user_id in(u,p_partner_id) and type_id=p_type_id) then raise exception 'Partner already linked for CP type';end if;
   if (select count(*) from public.cp_relationships where requested_by=u and accepted_at is null and ended_at is null)>=5 then raise exception 'CP request limit reached';end if;
   insert into public.cp_relationships(user_a,user_b,requested_by,type_id) values(least(u,p_partner_id),greatest(u,p_partner_id),u,p_type_id) returning * into relation;
  end if;
 elsif p_action='accept' then
  if relation.id is null or relation.requested_by=u or relation.accepted_at is not null then raise exception 'Incoming pending request required';end if;
  if exists(select 1 from phase3.cp_slots where user_id in(u,p_partner_id) and type_id=p_type_id) then raise exception 'Partner already linked for CP type';end if;
  if exists(select 1 from phase3.cp_slots s join phase3.cp_type_conflicts f on f.type_a=least(s.type_id,p_type_id) and f.type_b=greatest(s.type_id,p_type_id) where s.user_id in(u,p_partner_id)) then raise exception 'CP types conflict';end if;
  if exists(select 1 from public.cp_relationships r join phase3.cp_pair_type_conflicts f on f.type_a=least(r.type_id,p_type_id) and f.type_b=greatest(r.type_id,p_type_id) where r.user_a=relation.user_a and r.user_b=relation.user_b and r.accepted_at is not null and r.ended_at is null) then raise exception 'CP pair types conflict';end if;
  update public.cp_relationships set accepted_at=now() where id=relation.id returning * into relation;
  insert into phase3.cp_slots(user_id,type_id,relationship_id) values(relation.user_a,p_type_id,relation.id),(relation.user_b,p_type_id,relation.id);
  update public.cp_relationships set ended_at=now() where id<>relation.id and accepted_at is null and ended_at is null and type_id=p_type_id and (user_a in(u,p_partner_id) or user_b in(u,p_partner_id));
 else
  if relation.id is null then raise exception 'Relationship unavailable';end if;
  if p_action='reject' and (relation.accepted_at is not null or relation.requested_by=u) then raise exception 'Incoming pending request required';end if;
  update public.cp_relationships set ended_at=now() where id=relation.id returning * into relation;
  delete from phase3.cp_slots where relationship_id=relation.id;
 end if;
 answer:=to_jsonb(relation);
 insert into phase3.cp_requests(actor_id,request_id,payload,result) values(u,p_request_id,body,answer);
 insert into public.security_audit(actor_id,action,details) values(u,'cp_'||p_action,body||jsonb_build_object('relationship',relation.id,'request',p_request_id));
 return answer;
end $$;
create function phase3.cp_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();relations jsonb;
begin
 select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('type_label',t.label,'level',1+(select count(*) from unnest(t.level_thresholds) n where n<=r.gift_gold),'partner',jsonb_build_object('id',p.id,'display_name',p.display_name)) order by r.created_at desc),'[]'::jsonb) into relations
 from public.cp_relationships r join public.cp_types t on t.id=r.type_id join public.profiles p on p.id=case when r.user_a=u then r.user_b else r.user_a end
 where u in(r.user_a,r.user_b) and r.ended_at is null and (r.accepted_at is null or (exists(select 1 from phase3.cp_slots where relationship_id=r.id and user_id=r.user_a) and exists(select 1 from phase3.cp_slots where relationship_id=r.id and user_id=r.user_b)));
 return jsonb_build_object('types',(select coalesce(jsonb_agg(to_jsonb(t) order by t.id),'[]'::jsonb) from public.cp_types t where enabled),'relations',relations);
end $$;
revoke all on function phase3.assert_cp_gift(text,uuid),phase3.cp_action(uuid,text,text,uuid),phase3.cp_state() from public,anon,authenticated;
grant execute on function phase3.cp_action(uuid,text,text,uuid),phase3.cp_state() to authenticated;
create function public.phase4_cp_action(p_partner_id uuid,p_type_id text,p_action text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select phase3.cp_action(p_partner_id,p_type_id,p_action,p_request_id)$$;
create function public.phase4_cp_state() returns jsonb language sql security invoker set search_path='' as $$select phase3.cp_state()$$;
revoke all on function public.phase4_cp_action(uuid,text,text,uuid),public.phase4_cp_state() from public,anon;
grant execute on function public.phase4_cp_action(uuid,text,text,uuid),public.phase4_cp_state() to authenticated;

create or replace function phase3.send_gift(p_room_id uuid,p_recipient_id uuid,p_gift_id text,p_quantity integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); prior public.financial_operations%rowtype;
 g public.gift_catalog%rowtype; total bigint; debit bigint; credit bigint; op uuid; body jsonb; answer jsonb; member_count integer; cp_id uuid;
begin
 if p_request_id is null or p_room_id is null or p_recipient_id is null or p_gift_id is null or p_quantity is null or p_quantity not in(1,7,17,77,777) or p_recipient_id=u then raise exception 'Invalid gift request';end if;
 body:=jsonb_build_object('room',p_room_id,'recipient',p_recipient_id,'gift',p_gift_id,'quantity',p_quantity);
 perform pg_advisory_xact_lock(hashtextextended(u::text||p_request_id::text,0));
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if found then
  if prior.operation<>'gift' or prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;
 end if;
 if (select count(*) from public.financial_operations where actor_id=u and created_at>now()-interval '1 minute')>=30 then raise exception 'Rate limit exceeded';end if;
 if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=u) or not exists(select 1 from public.room_members where room_id=p_room_id and user_id=p_recipient_id) then raise exception 'Room membership required' using errcode='42501';end if;
 -- Hold both memberships throughout the transaction, including concurrent room exit.
 perform user_id from public.room_members where room_id=p_room_id and user_id in(u,p_recipient_id) order by user_id for share;
 get diagnostics member_count=row_count;
 if member_count<>2 then raise exception 'Room membership expired' using errcode='42501';end if;
 select * into g from public.gift_catalog where id=p_gift_id and is_active for share;
 if not found then raise exception 'Gift unavailable';end if;
 -- CP requires the relationship subsystem; never bypass its pairing rules.

 if not exists(select 1 from public.gift_categories where id=g.category_id and enabled) then raise exception 'Category unavailable';end if;
 total:=g.price*p_quantity;
 if total>9007199254740991 then raise exception 'Amount out of range';end if;
 perform user_id from public.wallets where user_id in(u,p_recipient_id) order by user_id for update;
 cp_id:=phase3.assert_cp_gift(g.relationship_type_id,p_recipient_id);
 update public.wallets set coins=coins-total,updated_at=now() where user_id=u and coins>=total returning coins into debit;
 if not found then raise exception 'Insufficient coins';end if;
 update public.wallets set diamonds=diamonds+total,updated_at=now() where user_id=p_recipient_id and diamonds<=9007199254740991-total returning diamonds into credit;
 if not found then raise exception 'Recipient wallet unavailable';end if;
 insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'gift',body) returning id into op;
 insert into public.gift_events(id,sender_id,recipient_id,room_id,gift_id,quantity,amount,diamond_source_type,relationship_id) values(op,u,p_recipient_id,p_room_id,g.id,p_quantity,total,g.diamond_source_type,cp_id);
 if cp_id is not null then update public.cp_relationships set gift_gold=gift_gold+total where id=cp_id;end if;
 insert into public.wallet_ledger(user_id,currency,amount_change,balance_after,operation_id,kind,transaction_id) values
 (u,'coins',-total,debit,gen_random_uuid(),'gift_sent',op),(p_recipient_id,'diamonds',total,credit,gen_random_uuid(),'gift_received',op);
 insert into public.security_audit(actor_id,operation_id,action,details) values(u,op,'gift_sent',body||jsonb_build_object('amount',total));
 answer:=jsonb_build_object('id',op,'status','completed','amount',total,'balance',debit,'gift_id',g.id,'quantity',p_quantity);
 update public.financial_operations set result=answer where id=op;
 return answer;
end $$;

