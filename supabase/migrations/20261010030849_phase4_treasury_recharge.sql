-- Owner cash issuance -> agent treasury -> customer wallet. No automatic cash verification.
create table phase3.treasury_accounts(user_id uuid primary key references auth.users(id),coins bigint not null default 0 check(coins between 0 and 9007199254740991),updated_at timestamptz not null default now());
create table phase3.coin_issuance(singleton boolean primary key default true check(singleton),issued bigint not null default 0 check(issued between 0 and 9007199254740991));
insert into phase3.coin_issuance(singleton) values(true);
create table phase3.treasury_ledger(id bigint generated always as identity primary key,user_id uuid not null references auth.users(id),operation_id uuid not null references public.financial_operations(id),amount bigint not null check(amount<>0),balance_after bigint not null check(balance_after>=0),created_at timestamptz not null default now());
create index treasury_ledger_user_created on phase3.treasury_ledger(user_id,created_at desc);
create index treasury_ledger_operation on phase3.treasury_ledger(operation_id);
create table public.recharge_requests(id uuid primary key references public.financial_operations(id),user_id uuid not null references auth.users(id),agency_id uuid not null references public.agencies(id),package_id uuid not null references public.recharge_packages(id),price_usd numeric not null check(price_usd>0),coins bigint not null check(coins>0),status text not null default 'pending' check(status in('pending','completed','failed')),cash_reference text,review_note text,reviewed_by uuid references auth.users(id),created_at timestamptz not null default now(),completed_at timestamptz,unique(agency_id,cash_reference));
create index recharge_request_user_month on public.recharge_requests(user_id,completed_at);
create index recharge_request_agency_pending on public.recharge_requests(agency_id,status,created_at);
create index recharge_request_package on public.recharge_requests(package_id);
create index recharge_request_reviewer on public.recharge_requests(reviewed_by);
create table public.recharge_reward_claims(user_id uuid not null references auth.users(id),tier_id text not null references public.recharge_reward_tiers(id),month_start date not null,operation_id uuid not null references public.financial_operations(id),rewards jsonb not null,created_at timestamptz not null default now(),primary key(user_id,tier_id,month_start));
create index reward_claim_operation on public.recharge_reward_claims(operation_id);
create table public.reward_fulfillment(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),operation_id uuid not null references public.financial_operations(id),reward jsonb not null,status text not null default 'pending' check(status in('pending','fulfilled')),decision_note text,completed_by uuid references auth.users(id),created_at timestamptz not null default now(),completed_at timestamptz);
create index reward_fulfillment_user on public.reward_fulfillment(user_id,created_at desc);
create index reward_fulfillment_operation on public.reward_fulfillment(operation_id);
create index reward_fulfillment_reviewer on public.reward_fulfillment(completed_by);
alter table phase3.treasury_accounts enable row level security;alter table phase3.coin_issuance enable row level security;alter table phase3.treasury_ledger enable row level security;
alter table public.recharge_requests enable row level security;alter table public.recharge_reward_claims enable row level security;alter table public.reward_fulfillment enable row level security;
revoke all on phase3.treasury_accounts,phase3.coin_issuance,phase3.treasury_ledger,public.recharge_requests,public.recharge_reward_claims,public.reward_fulfillment from public,anon,authenticated;
create function phase3.recharge_action(p_action text,p_data jsonb,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
<<recharge_action>>
declare u uuid:=phase3.actor();own boolean:=phase3.is_owner();management boolean:=(phase3.admin_session()->>'canManageRechargeAgencies')::boolean;prior public.financial_operations%rowtype;body jsonb;op uuid;answer jsonb;target uuid;amount bigint;balance bigint;id uuid;agency public.agencies%rowtype;pack public.recharge_packages%rowtype;req public.recharge_requests%rowtype;month_start date;total_usd numeric;tier public.recharge_reward_tiers%rowtype;reward jsonb;tiers jsonb:='[]';bonus bigint:=0;coin_credit bigint;item public.store_catalog%rowtype;expiry timestamptz;note text:=btrim(p_data->>'note');reference text:=btrim(p_data->>'cash_reference');
begin
 if p_action is null or p_data is null or jsonb_typeof(p_data)<>'object' or p_request_id is null then raise exception 'Invalid recharge action';end if;
 body:=jsonb_build_object('action',p_action,'data',p_data);
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if found then if prior.operation<>'recharge_action' or prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;end if;
 if (select count(*) from public.financial_operations where actor_id=u and created_at>now()-interval '1 minute')>=30 then raise exception 'Rate limit exceeded';end if;
 if p_action in('issue','allocate') then
  if not own then raise exception 'Owner only' using errcode='42501';end if;
  amount:=(p_data->>'coins')::bigint;if amount is null or amount not between 1 and 9007199254740991 or coalesce(char_length(note),0) not between 10 and 500 then raise exception 'Positive amount and documented cash decision required';end if;
  if p_action='issue' then
   if coalesce(char_length(reference),0) not between 3 and 120 then raise exception 'Cash reference required';end if;
   if exists(select 1 from public.financial_operations where operation='recharge_action' and payload->>'action'='issue' and payload->'data'->>'cash_reference'=reference) then raise exception 'Cash issuance reference already used';end if;
   insert into phase3.treasury_accounts(user_id) values(u) on conflict do nothing;
   update phase3.coin_issuance set issued=issued+amount where singleton;
   update phase3.treasury_accounts set coins=coins+amount,updated_at=now() where user_id=u returning coins into balance;
  else
   select * into agency from public.agencies where id=(p_data->>'agency_id')::uuid and kind='recharge' and is_active for share;if not found then raise exception 'Active recharge agency required';end if;target:=agency.owner_id;if target=u then raise exception 'Cannot allocate to own treasury';end if;
   insert into phase3.treasury_accounts(user_id) values(u),(target) on conflict do nothing;
   perform user_id from phase3.treasury_accounts where user_id in(u,target) order by user_id for update;
   update phase3.treasury_accounts set coins=coins-amount,updated_at=now() where user_id=u and coins>=amount returning coins into balance;if not found then raise exception 'Insufficient Owner treasury';end if;
   update phase3.treasury_accounts set coins=coins+amount,updated_at=now() where user_id=target;
  end if;
  insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'recharge_action',body) returning financial_operations.id into op;
  insert into phase3.treasury_ledger(user_id,operation_id,amount,balance_after) values(u,op,case when p_action='issue' then amount else -amount end,balance);
  if p_action='allocate' then insert into phase3.treasury_ledger(user_id,operation_id,amount,balance_after) select target,op,amount,coins from phase3.treasury_accounts where user_id=target;end if;
  answer:=jsonb_build_object('id',op,'status','completed','coins',amount);
 elsif p_action='request' then
  select * into agency from public.agencies where id=(p_data->>'agency_id')::uuid and kind='recharge' and is_active for share;if not found then raise exception 'Active recharge agency required';end if;
  select * into pack from public.recharge_packages where recharge_packages.id=(p_data->>'package_id')::uuid and is_active for share;
  if not found or pack.gold_amount<>(p_data->>'expected_coins')::bigint or pack.price_usd<>(p_data->>'expected_price_usd')::numeric or p_data->>'expected_coins' is null or p_data->>'expected_price_usd' is null then raise exception 'Package changed; confirm current price';end if;
  if (select count(*) from public.recharge_requests where user_id=u and status='pending')>=5 then raise exception 'Resolve pending recharge requests first';end if;
  insert into public.financial_operations(actor_id,request_id,operation,payload,status) values(u,p_request_id,'recharge_action',body,'pending') returning financial_operations.id into op;
  insert into public.recharge_requests(id,user_id,agency_id,package_id,price_usd,coins) values(op,u,agency.id,pack.id,pack.price_usd,pack.gold_amount);
  answer:=jsonb_build_object('id',op,'status','pending');
 elsif p_action in('approve','reject','cancel') then
  id:=(p_data->>'id')::uuid;select * into req from public.recharge_requests where recharge_requests.id=recharge_action.id;
  if not found then raise exception 'Recharge request not found';end if;
  -- Wallet before request locks: same ordering as gifts and agency transfers.
  perform user_id from public.wallets where user_id=req.user_id for update;
  select * into req from public.recharge_requests where recharge_requests.id=recharge_action.id for update;
  select * into agency from public.agencies where agencies.id=req.agency_id for share;
  if p_action='cancel' then if req.user_id<>u then raise exception 'Request owner only' using errcode='42501';end if;
  else if agency.owner_id<>u then raise exception 'Responsible recharge agent only' using errcode='42501';end if;end if;
  if req.status<>'pending' then raise exception 'Request already resolved';end if;
  if coalesce(char_length(note),0) not between 3 and 500 then raise exception 'Decision note required';end if;
  if p_action='approve' then
   if not agency.is_active or coalesce(char_length(reference),0) not between 3 and 120 then raise exception 'Active agency and cash receipt required';end if;
   if not exists(select 1 from auth.users where auth.users.id=req.user_id and email_confirmed_at is not null and deleted_at is null and not is_anonymous and (banned_until is null or banned_until<now())) then raise exception 'Verified recipient required';end if;
   select * into pack from public.recharge_packages where recharge_packages.id=req.package_id and is_active for share;if not found or pack.gold_amount<>req.coins or pack.price_usd<>req.price_usd then raise exception 'Package changed; customer must submit a new confirmation';end if;
   month_start:=date_trunc('month',now() at time zone 'UTC')::date;
   select coalesce(sum(price_usd),0)+req.price_usd into total_usd from public.recharge_requests where user_id=req.user_id and status='completed' and completed_at>=month_start::timestamp at time zone 'UTC' and completed_at<(month_start+interval '1 month')::timestamp at time zone 'UTC';
   for tier in select t.* from public.recharge_reward_tiers t where t.threshold_usd<=total_usd and not exists(select 1 from public.recharge_reward_claims c where c.user_id=req.user_id and c.tier_id=t.id and c.month_start=recharge_action.month_start) order by t.threshold_usd,t.id for share loop
    tiers:=tiers||jsonb_build_array(to_jsonb(tier));for reward in select value from jsonb_array_elements(tier.rewards) loop
     if reward->>'type'='coins' then amount:=(reward->>'coins')::bigint;if amount is null or amount<1 then raise exception 'Invalid configured coin reward';end if;bonus:=bonus+amount;end if;
    end loop;
   end loop;
   coin_credit:=req.coins+bonus;
   update phase3.treasury_accounts set coins=coins-coin_credit,updated_at=now() where user_id=u and coins>=coin_credit returning coins into balance;if not found then raise exception 'Insufficient agent treasury including reward coins';end if;
   update public.wallets set coins=coins+coin_credit,updated_at=now() where user_id=req.user_id returning coins into amount;
   insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'recharge_action',body) returning financial_operations.id into op;
   insert into phase3.treasury_ledger(user_id,operation_id,amount,balance_after) values(u,op,-coin_credit,balance);
   insert into public.wallet_ledger(user_id,currency,amount_change,balance_after,operation_id,transaction_id,kind) values(req.user_id,'coins',coin_credit,amount,gen_random_uuid(),op,'agent_topup');
   for reward in select value from jsonb_array_elements(tiers) loop
    insert into public.recharge_reward_claims(user_id,tier_id,month_start,operation_id,rewards) values(req.user_id,reward->>'id',month_start,op,reward->'rewards');
   end loop;
   for reward in select value from jsonb_array_elements((select coalesce(jsonb_agg(x),'[]') from jsonb_array_elements(tiers) t cross join lateral jsonb_array_elements(t->'rewards') x)) loop
    if reward->>'type' in('vip','cosmetic') then
     select * into item from public.store_catalog where store_catalog.id=case when reward->>'type'='vip' then 'vip'||(reward->>'vipLevel') else reward->>'catalog_id' end and is_active for share;
     if not found or (reward->>'type'='vip' and item.category<>'vip') or (reward->>'type'='cosmetic' and not item.is_reward) or reward->>'days' is null or (reward->>'days')::integer not between 1 and 366 then raise exception 'Reward catalog configuration invalid';end if;
     select greatest(now(),coalesce(expires_at,now()))+make_interval(days=>(reward->>'days')::integer) into expiry from public.store_ownership where user_id=req.user_id and item_id=item.id;
     expiry:=coalesce(expiry,now()+make_interval(days=>(reward->>'days')::integer));
     insert into public.store_ownership(user_id,item_id,operation_id,expires_at) values(req.user_id,item.id,op,expiry) on conflict(user_id,item_id) do update set expires_at=excluded.expires_at,operation_id=excluded.operation_id;
     if item.category='vip' and not exists(select 1 from public.store_ownership o join public.store_catalog c on c.id=o.item_id where o.user_id=req.user_id and c.category='vip' and c.vip_level>item.vip_level and (o.expires_at is null or o.expires_at>now())) then
      update public.store_ownership o set equipped=false from public.store_catalog c where o.user_id=req.user_id and c.id=o.item_id and c.category='vip';update public.store_ownership set equipped=true where user_id=req.user_id and item_id=item.id;
     end if;
    elsif reward->>'type'='request' then insert into public.reward_fulfillment(user_id,operation_id,reward) values(req.user_id,op,reward);
    elsif reward->>'type'<>'coins' or reward->>'type' is null then raise exception 'Unsupported configured reward';end if;
   end loop;
   update public.recharge_requests set status='completed',cash_reference=reference,review_note=note,reviewed_by=u,completed_at=now() where recharge_requests.id=recharge_action.id;
   answer:=jsonb_build_object('id',op,'request_id',req.id,'status','completed','coins',req.coins,'bonus_coins',bonus,'reward_tiers',tiers);
  else
   insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'recharge_action',body) returning financial_operations.id into op;
   update public.recharge_requests set status='failed',review_note=note,reviewed_by=u where recharge_requests.id=recharge_action.id;answer:=jsonb_build_object('id',op,'request_id',req.id,'status','failed');
  end if;
  update public.financial_operations set status=answer->>'status',result=jsonb_build_object('id',req.id,'status',answer->>'status') where financial_operations.id=req.id;
 elsif p_action='fulfill_reward' then
  if not management then raise exception 'Recharge management required' using errcode='42501';end if;
  if coalesce(char_length(note),0) not between 10 and 500 then raise exception 'Fulfillment evidence note required';end if;
  update public.reward_fulfillment set status='fulfilled',decision_note=note,completed_by=u,completed_at=now() where reward_fulfillment.id=(p_data->>'id')::uuid and status='pending' returning reward_fulfillment.id into id;if not found then raise exception 'Pending reward not found';end if;
  insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'recharge_action',body) returning financial_operations.id into op;answer:=jsonb_build_object('id',op,'reward_id',id,'status','completed');
 else raise exception 'Unsupported recharge action';end if;
 insert into public.security_audit(actor_id,operation_id,action,details) values(u,op,'recharge_'||p_action,body||answer);
 update public.financial_operations set result=answer where financial_operations.id=op;return answer;
end $$;
create function phase3.recharge_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();management boolean:=(phase3.admin_session()->>'canManageRechargeAgencies')::boolean;own boolean:=phase3.is_owner();
begin
 return jsonb_build_object('isOwner',own,'canManage',management,'treasury',coalesce((select coins from phase3.treasury_accounts where user_id=u),0),'issued',case when own then (select issued from phase3.coin_issuance where singleton) else null end,
 'agencies',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'owner_id',owner_id)),'[]') from public.agencies where kind='recharge' and is_active),
 'packages',(select coalesce(jsonb_agg(to_jsonb(p) order by price_usd),'[]') from public.recharge_packages p where is_active),
 'requests',(select coalesce(jsonb_agg(to_jsonb(r)),'[]') from (select q.* from public.recharge_requests q join public.agencies a on a.id=q.agency_id where q.user_id=u or a.owner_id=u or management order by q.created_at desc limit 100) r),
 'claims',(select coalesce(jsonb_agg(to_jsonb(c)),'[]') from (select * from public.recharge_reward_claims where user_id=u order by created_at desc limit 100) c),
 'fulfillment',(select coalesce(jsonb_agg(to_jsonb(f)),'[]') from (select * from public.reward_fulfillment where user_id=u or management order by created_at desc limit 100) f),
 'ledger',(select coalesce(jsonb_agg(to_jsonb(l)),'[]') from (select * from phase3.treasury_ledger where user_id=u order by created_at desc limit 100) l));
end $$;
revoke all on function phase3.recharge_action(text,jsonb,uuid),phase3.recharge_state() from public,anon;
grant execute on function phase3.recharge_action(text,jsonb,uuid),phase3.recharge_state() to authenticated;
create function public.phase4_recharge_action(p_action text,p_data jsonb,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select phase3.recharge_action(p_action,p_data,p_request_id)$$;
create function public.phase4_recharge_state() returns jsonb language sql security invoker set search_path='' as $$select phase3.recharge_state()$$;
revoke all on function public.phase4_recharge_action(text,jsonb,uuid),public.phase4_recharge_state() from public,anon;
grant execute on function public.phase4_recharge_action(text,jsonb,uuid),public.phase4_recharge_state() to authenticated;
