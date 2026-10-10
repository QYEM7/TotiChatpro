-- Privileged implementations stay outside the exposed API schema.
create schema if not exists phase3;
revoke all on schema phase3 from public,anon;
grant usage on schema phase3 to authenticated;
create table public.financial_operations (
 id uuid primary key default gen_random_uuid(), actor_id uuid not null references auth.users(id),
 request_id uuid not null, operation text not null, payload jsonb not null,
 status text not null default 'completed' check(status in ('pending','completed','failed','refunded')),
 result jsonb not null default '{}', created_at timestamptz not null default now(),
 unique(actor_id,request_id)
);
create table public.gift_events (
 id uuid primary key references public.financial_operations(id),
 sender_id uuid not null references auth.users(id), recipient_id uuid not null references auth.users(id),
 room_id uuid not null references public.rooms(id), gift_id text not null references public.gift_catalog(id),
 quantity integer not null check(quantity in(1,7,17,77,777)), amount bigint not null check(amount>0),
 diamond_source_type text not null check(diamond_source_type in('FIXED_GIFT','LUCKY_GIFT')),
 created_at timestamptz not null default now(),check(sender_id<>recipient_id)
);
create table public.security_audit (
 id bigint generated always as identity primary key, actor_id uuid references auth.users(id),
 operation_id uuid references public.financial_operations(id), action text not null,
 details jsonb not null default '{}',created_at timestamptz not null default now()
);
alter table public.wallet_ledger add column transaction_id uuid references public.financial_operations(id);
create index ledger_transaction_idx on public.wallet_ledger(transaction_id);
create index operations_actor_created_idx on public.financial_operations(actor_id,created_at desc);
create index gift_events_sender_idx on public.gift_events(sender_id,created_at desc);
create index gift_events_recipient_idx on public.gift_events(recipient_id,created_at desc);
create index gift_events_room_idx on public.gift_events(room_id);
create index gift_events_catalog_idx on public.gift_events(gift_id);
create index audit_actor_idx on public.security_audit(actor_id,created_at desc);
create index audit_operation_idx on public.security_audit(operation_id);
alter table public.financial_operations enable row level security;
alter table public.gift_events enable row level security;
alter table public.security_audit enable row level security;
revoke all on public.financial_operations,public.gift_events,public.security_audit from public,anon,authenticated;
grant select on public.financial_operations,public.gift_events to authenticated;
create policy operation_owner on public.financial_operations for select to authenticated using(actor_id=(select auth.uid()));
create policy gift_participant on public.gift_events for select to authenticated using(sender_id=(select auth.uid()) or recipient_id=(select auth.uid()));
create function phase3.actor() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from auth.users where id=u and email_confirmed_at is not null and not is_anonymous and (banned_until is null or banned_until<now())) then raise exception 'Verified account required' using errcode='42501'; end if;
 if not exists(select 1 from auth.sessions where user_id=u and id=(auth.jwt()->>'session_id')::uuid) then raise exception 'Session expired' using errcode='42501';end if;
 if exists(select 1 from auth.mfa_factors where user_id=u and status='verified') and auth.jwt()->>'aal'<>'aal2' then raise exception 'Two-factor verification required' using errcode='42501';end if;
 return u;
end $$;
create function phase3.send_gift(p_room_id uuid,p_recipient_id uuid,p_gift_id text,p_quantity integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); prior public.financial_operations%rowtype;
 g public.gift_catalog%rowtype; total bigint; debit bigint; credit bigint; op uuid; body jsonb; answer jsonb;
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
 select * into g from public.gift_catalog where id=p_gift_id and is_active for share;
 if not found then raise exception 'Gift unavailable';end if;
 -- CP requires the relationship subsystem; never bypass its pairing rules.
 if g.relationship_type_id is not null then raise exception 'A confirmed CP relationship is required';end if;
 if not exists(select 1 from public.gift_categories where id=g.category_id and enabled) then raise exception 'Category unavailable';end if;
 total:=g.price*p_quantity;
 if total>9007199254740991 then raise exception 'Amount out of range';end if;
 perform user_id from public.wallets where user_id in(u,p_recipient_id) order by user_id for update;
 update public.wallets set coins=coins-total,updated_at=now() where user_id=u and coins>=total returning coins into debit;
 if not found then raise exception 'Insufficient coins';end if;
 update public.wallets set diamonds=diamonds+total,updated_at=now() where user_id=p_recipient_id and diamonds<=9007199254740991-total returning diamonds into credit;
 if not found then raise exception 'Recipient wallet unavailable';end if;
 insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'gift',body) returning id into op;
 insert into public.gift_events(id,sender_id,recipient_id,room_id,gift_id,quantity,amount,diamond_source_type) values(op,u,p_recipient_id,p_room_id,g.id,p_quantity,total,g.diamond_source_type);
 insert into public.wallet_ledger(user_id,currency,amount_change,balance_after,operation_id,kind,transaction_id) values
 (u,'coins',-total,debit,gen_random_uuid(),'gift_sent',op),(p_recipient_id,'diamonds',total,credit,gen_random_uuid(),'gift_received',op);
 insert into public.security_audit(actor_id,operation_id,action,details) values(u,op,'gift_sent',body||jsonb_build_object('amount',total));
 answer:=jsonb_build_object('id',op,'status','completed','amount',total,'balance',debit,'gift_id',g.id,'quantity',p_quantity);
 update public.financial_operations set result=answer where id=op;
 return answer;
end $$;
revoke all on function phase3.actor(),phase3.send_gift(uuid,uuid,text,integer,uuid) from public,anon,authenticated;
grant execute on function phase3.send_gift(uuid,uuid,text,integer,uuid) to authenticated;
create function public.phase3_send_gift(p_room_id uuid,p_recipient_id uuid,p_gift_id text,p_quantity integer,p_request_id uuid)
returns jsonb language sql security invoker set search_path='' as $$select phase3.send_gift(p_room_id,p_recipient_id,p_gift_id,p_quantity,p_request_id)$$;
revoke all on function public.phase3_send_gift(uuid,uuid,text,integer,uuid) from public,anon;
grant execute on function public.phase3_send_gift(uuid,uuid,text,integer,uuid) to authenticated;
