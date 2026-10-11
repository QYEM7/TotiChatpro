-- Staging-only forward migration. Preserves the exact current financial and authorization
-- procedures from Staging with only per-actor serialization, and SHA-256
-- support retry fingerprints. No payroll, balances, agency roles or rates change.
-- Created from inspected phase3 definitions while Staging had zero support requests.
-- Applies to disposable local replay and the independent Staging project only.

CREATE OR REPLACE FUNCTION phase3.agency_action(p_action text, p_data jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<agency_action>>
declare u uuid:=phase3.actor();body jsonb;prior phase3.agency_requests%rowtype;reg public.agency_registrations%rowtype;a public.agencies%rowtype;j public.agency_join_requests%rowtype;kind text;name text;note text;commission numeric;old_id uuid;id uuid;answer jsonb;
begin
 -- Verify actor before lock through phase3.actor(); serialize sensitive retries by session owner.
 perform pg_advisory_xact_lock(hashtextextended('totichat-agency_action:'||u::text,0));
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
  if not (
  phase3.can_manage_agency(reg.kind) or
  (
    p_action='approve_registration' and reg.kind='host' and
    exists (
      select 1 from phase3.admin_access db_staff
      where db_staff.user_id=u and db_staff.role='db'
        and 'host_agency.open'=any(db_staff.permissions)
    )
  )
 ) then raise exception 'Agency management permission required' using errcode='42501';end if;
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
end $function$;

CREATE OR REPLACE FUNCTION phase3.recharge_action(p_action text, p_data jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
<<recharge_action>>
declare u uuid:=phase3.actor();own boolean:=phase3.is_owner();management boolean:=(phase3.admin_session()->>'canManageRechargeAgencies')::boolean;prior public.financial_operations%rowtype;body jsonb;op uuid;answer jsonb;target uuid;amount bigint;balance bigint;id uuid;agency public.agencies%rowtype;pack public.recharge_packages%rowtype;req public.recharge_requests%rowtype;month_start date;total_usd numeric;tier public.recharge_reward_tiers%rowtype;reward jsonb;tiers jsonb:='[]';bonus bigint:=0;coin_credit bigint;item public.store_catalog%rowtype;expiry timestamptz;note text:=btrim(p_data->>'note');reference text:=btrim(p_data->>'cash_reference');
begin
 -- Verify actor before lock through phase3.actor(); serialize sensitive retries by session owner.
 perform pg_advisory_xact_lock(hashtextextended('totichat-recharge_action:'||u::text,0));
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
   if exists(select 1 from public.financial_operations where operation='recharge_action' and payload->>'action'='issue' and btrim(payload->'data'->>'cash_reference')=reference) then raise exception 'Cash issuance reference already used';end if;
   insert into phase3.treasury_accounts(user_id) values(u) on conflict do nothing;
   update phase3.coin_issuance set issued=issued+amount where singleton;
   update phase3.treasury_accounts set coins=coins+amount,updated_at=now() where user_id=u returning coins into balance;
  else
   select * into agency from public.agencies where agencies.id=(p_data->>'agency_id')::uuid and kind='recharge' and is_active for share;if not found then raise exception 'Active recharge agency required';end if;target:=agency.owner_id;if target=u then raise exception 'Cannot allocate to own treasury';end if;
   insert into phase3.treasury_accounts(user_id) values(u),(target) on conflict do nothing;
   perform user_id from phase3.treasury_accounts where user_id in(u,target) order by user_id for update;
   update phase3.treasury_accounts set coins=coins-amount,updated_at=now() where user_id=u and coins>=amount returning coins into balance;if not found then raise exception 'Insufficient Owner treasury';end if;
   update phase3.treasury_accounts set coins=coins+amount,updated_at=now() where user_id=target;
  end if;
  insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'recharge_action',body) returning financial_operations.id into op;
  insert into phase3.treasury_ledger(user_id,operation_id,amount,balance_after) values(u,op,case when p_action='issue' then amount else -amount end,balance);
  if p_action='allocate' then insert into phase3.treasury_ledger(user_id,operation_id,amount,balance_after) select target,op,amount,coins from phase3.treasury_accounts where user_id=target;end if;
  if p_action='issue' then insert into phase3.issuance_ledger(operation_id,amount,balance_after) select op,-amount,-issued from phase3.coin_issuance where singleton;end if;
  answer:=jsonb_build_object('id',op,'status','completed','coins',amount);
 elsif p_action='request' then
  select * into agency from public.agencies where agencies.id=(p_data->>'agency_id')::uuid and kind='recharge' and is_active for share;if not found then raise exception 'Active recharge agency required';end if;
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
   update public.wallets set coins=coins+coin_credit,updated_at=now() where user_id=req.user_id and coins<=9007199254740991-coin_credit returning coins into amount;if not found then raise exception 'Customer balance limit exceeded';end if;
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
end $function$;

CREATE OR REPLACE FUNCTION phase3.support_action(p_action text, p_data jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=phase3.actor(); prev phase3.support_requests%rowtype;
 payload jsonb; answer jsonb; t public.support_tickets%rowtype; target_id uuid;
 name text; content text; cat text;
begin
 -- Verify actor before lock through phase3.actor(); serialize sensitive retries by session owner.
 perform pg_advisory_xact_lock(hashtextextended('totichat-support_action:'||u::text,0));
 if p_action not in('create','reply','status','staff_grant','staff_revoke') or p_request_id is null or
 p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>8500 then raise exception 'Invalid support action';end if;
 -- Do not duplicate support-message plaintext in the private idempotency log.
 payload:=jsonb_build_object('sha256',
  encode(sha256(convert_to(jsonb_build_object('action',p_action,'data',p_data)::text,'UTF8')),'hex'));
 select * into prev from phase3.support_requests where actor_id=u and request_id=p_request_id;
 if found then
  -- Historical raw retry payloads remain retry-compatible; new requests store SHA only.
  if prev.payload<>payload
   and prev.payload<>jsonb_build_object('action',p_action,'data',p_data)
   then raise exception 'Request key conflict';end if;
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
end $function$;

-- All private helpers retain their previous grants; no permissions broadened.
comment on function phase3.support_action(text,jsonb,uuid) is
 'Staging support RPC with verified-actor serialization and hashed retry fingerprint; ticket plaintext stored only in support_messages.';
