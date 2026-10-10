alter table public.wallets add column silver bigint not null default 0 check(silver>=0 and silver<=9007199254740991);
alter table public.wallet_ledger drop constraint wallet_ledger_currency_check;
alter table public.wallet_ledger add constraint wallet_ledger_currency_check check(currency in('coins','diamonds','silver'));
create table public.store_ownership (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
 item_id text not null references public.store_catalog(id),
 operation_id uuid not null references public.financial_operations(id),
 expires_at timestamptz,equipped boolean not null default false,
 created_at timestamptz not null default now(),unique(user_id,item_id)
);
create index store_ownership_item_idx on public.store_ownership(item_id);
create index store_ownership_operation_idx on public.store_ownership(operation_id);
alter table public.store_ownership enable row level security;
revoke all on public.store_ownership from public,anon,authenticated;
grant select on public.store_ownership to authenticated;
create policy ownership_self on public.store_ownership for select to authenticated using(user_id=(select auth.uid()));
create function phase3.purchase_store(p_item_id text,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); prior public.financial_operations%rowtype; item public.store_catalog%rowtype;
 owned public.store_ownership%rowtype; op uuid; bal bigint; expiry timestamptz; body jsonb; answer jsonb;
begin
 if p_item_id is null or p_request_id is null then raise exception 'Invalid purchase';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 body:=jsonb_build_object('item',p_item_id);
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if found then if prior.operation<>'store_purchase' or prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;end if;
 if (select count(*) from public.financial_operations where actor_id=u and created_at>now()-interval '1 minute')>=30 then raise exception 'Rate limit exceeded';end if;
 select * into item from public.store_catalog where id=p_item_id and is_active and not is_reward for share;
 if not found then raise exception 'Item unavailable';end if;
 if item.relationship_type_id is not null then raise exception 'Confirmed CP relationship required';end if;
 perform user_id from public.wallets where user_id=u for update;
 select * into owned from public.store_ownership where user_id=u and item_id=p_item_id for update;
 if found and owned.expires_at is null then raise exception 'Item already owned';end if;
 if item.category='vip' and exists(select 1 from public.store_ownership o join public.store_catalog c on c.id=o.item_id where o.user_id=u and c.category='vip' and c.vip_level>item.vip_level and (o.expires_at is null or o.expires_at>now())) then raise exception 'VIP downgrade prohibited';end if;
 if item.duration_days is not null then expiry:=greatest(now(),coalesce(owned.expires_at,now()))+make_interval(days=>item.duration_days);end if;
 if item.currency='gold' then update public.wallets set coins=coins-item.price,updated_at=now() where user_id=u and coins>=item.price returning coins into bal;
 else update public.wallets set silver=silver-item.price,updated_at=now() where user_id=u and silver>=item.price returning silver into bal;end if;
 if not found then raise exception 'Insufficient balance';end if;
 insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'store_purchase',body) returning id into op;
 insert into public.store_ownership(user_id,item_id,operation_id,expires_at) values(u,p_item_id,op,expiry)
 on conflict(user_id,item_id) do update set expires_at=excluded.expires_at,operation_id=excluded.operation_id;
 insert into public.wallet_ledger(user_id,currency,amount_change,balance_after,operation_id,transaction_id,kind) values(u,case item.currency when 'gold' then 'coins' else 'silver' end,-item.price,bal,gen_random_uuid(),op,'store_purchase');
 insert into public.security_audit(actor_id,operation_id,action,details) values(u,op,'store_purchase',body||jsonb_build_object('price',item.price,'currency',item.currency));
 answer:=jsonb_build_object('id',op,'status','completed','item_id',p_item_id,'price',item.price,'currency',item.currency,'expires_at',expiry);
 update public.financial_operations set result=answer where id=op;return answer;
end $$;
create function phase3.equip_store(p_item_id text,p_equipped boolean) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); cat text;
begin
 if p_equipped is null then raise exception 'Invalid equipment state';end if;
 perform user_id from public.wallets where user_id=u for update;
 select c.category into cat from public.store_ownership o join public.store_catalog c on c.id=o.item_id where o.user_id=u and o.item_id=p_item_id and c.is_active and (o.expires_at is null or o.expires_at>now()) for update of o;
 if cat is null then raise exception 'Active ownership required';end if;
 if p_equipped then update public.store_ownership o set equipped=false from public.store_catalog c where o.item_id=c.id and o.user_id=u and c.category=cat;end if;
 update public.store_ownership set equipped=p_equipped where user_id=u and item_id=p_item_id;
 insert into public.security_audit(actor_id,action,details) values(u,'store_equipment',jsonb_build_object('item',p_item_id,'equipped',p_equipped));
end $$;
revoke all on function phase3.purchase_store(text,uuid),phase3.equip_store(text,boolean) from public,anon;
grant execute on function phase3.purchase_store(text,uuid),phase3.equip_store(text,boolean) to authenticated;
create function public.phase3_purchase_store(p_item_id text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select phase3.purchase_store(p_item_id,p_request_id)$$;
create function public.phase3_equip_store(p_item_id text,p_equipped boolean) returns void language sql security invoker set search_path='' as $$select phase3.equip_store(p_item_id,p_equipped)$$;
revoke all on function public.phase3_purchase_store(text,uuid),public.phase3_equip_store(text,boolean) from public,anon;
grant execute on function public.phase3_purchase_store(text,uuid),public.phase3_equip_store(text,boolean) to authenticated;
-- Serialize operations per actor for exact rate limiting and idempotency across kinds.
create or replace function phase3.actor() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from auth.users where id=u and email_confirmed_at is not null and not coalesce(is_anonymous,false) and (banned_until is null or banned_until<now())) then raise exception 'Verified account required' using errcode='42501';end if;
 if not exists(select 1 from auth.sessions where user_id=u and id=(auth.jwt()->>'session_id')::uuid) then raise exception 'Session expired' using errcode='42501';end if;
 if exists(select 1 from auth.mfa_factors where user_id=u and status='verified') and coalesce(auth.jwt()->>'aal','')<>'aal2' then raise exception 'Two-factor verification required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));return u;
end $$;
