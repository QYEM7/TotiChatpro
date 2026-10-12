-- STAGING ONLY. Lucky gift draw is a NON-REDEEMABLE points reward.
-- Base gift diamonds alone are recorded in wallets/agency targets. Never multiply wallet diamonds.
create table if not exists phase3.lucky_settings(
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 version integer not null default 1 check(version>0),
 updated_at timestamptz not null default now()
);
insert into phase3.lucky_settings(singleton,enabled) values(true,false) on conflict(singleton) do nothing;
create table if not exists phase3.lucky_reward_tiers(
 tier text primary key check(tier ~ '^[a-z][a-z0-9_]{0,24}$'),
 label text not null check(length(label) between 1 and 70),
 weight integer not null check(weight between 1 and 10000),
 multiplier integer not null check(multiplier between 1 and 100),
 max_daily_wins integer check(max_daily_wins is null or max_daily_wins between 1 and 10000),
 sort_order integer not null check(sort_order between 0 and 100)
);
create table if not exists phase3.lucky_awards(
 gift_event_id uuid primary key references public.gift_events(id) on delete restrict,
 event_id uuid not null unique default gen_random_uuid(),
 sender_id uuid not null references auth.users(id),
 recipient_id uuid not null references auth.users(id),
 room_id uuid not null references public.rooms(id),
 gift_id text not null references public.gift_catalog(id),
 quantity integer not null,
 base_coins bigint not null check(base_coins>0),
 bonus_points bigint not null check(bonus_points>=0),
 reward_tier text not null,
 multiplier integer not null,
 odds_weight integer not null,
 rules_version integer not null,
 created_at timestamptz not null default now()
);
create index if not exists tc_lucky_awards_recipient_daily on phase3.lucky_awards(recipient_id,created_at desc,reward_tier);
create table if not exists phase3.lucky_config_requests(
 actor_id uuid not null references auth.users(id),
 request_id uuid not null,
 payload jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
alter table phase3.lucky_settings enable row level security;
alter table phase3.lucky_reward_tiers enable row level security;
alter table phase3.lucky_awards enable row level security;
alter table phase3.lucky_config_requests enable row level security;
revoke all on phase3.lucky_settings,phase3.lucky_reward_tiers,phase3.lucky_awards,phase3.lucky_config_requests from public,anon,authenticated;
-- Explicitly provisional staging pilot NON-CASH point odds (100% weight=10000).
-- These are never silently deployed to production; Owner may replace them in the app.
insert into phase3.lucky_reward_tiers(tier,label,weight,multiplier,max_daily_wins,sort_order)
values ('spark','نجمة الحظ',8000,1,null,0),('double','حظ مضاعف',1700,2,30,1),('royal','التاج الملكي',300,5,5,2)
on conflict(tier) do nothing;
create or replace function phase3.lucky_policy_read()
returns jsonb language plpgsql security definer set search_path = ''
as $f$
declare me uuid:=phase3.actor(); cfg phase3.lucky_settings%rowtype;
begin
 select * into cfg from phase3.lucky_settings where singleton;
 return jsonb_build_object('enabled',cfg.enabled,'currency','LUCKY_POINTS_NON_REDEEMABLE',
  'rule','Base diamonds stay equal to gift coins, Lucky bonus is noncash points only, never in agency targets or salaries.',
  'version',cfg.version,'tiers',coalesce((select jsonb_agg(
    jsonb_build_object('rewardTier',tier,'label',label,'weight',weight,'multiplier',multiplier,
    'maxDailyWins',max_daily_wins) order by sort_order,tier)
     from phase3.lucky_reward_tiers),'[]'::jsonb));
end $f$;
revoke all on function phase3.lucky_policy_read() from public,anon;
grant execute on function phase3.lucky_policy_read() to authenticated;
create or replace function public.phase6_lucky_gift_policy()
returns jsonb language sql security invoker set search_path = ''
as $f$ select phase3.lucky_policy_read() $f$;
revoke all on function public.phase6_lucky_gift_policy() from public,anon;
grant execute on function public.phase6_lucky_gift_policy() to authenticated;
create or replace function phase3.reject_unapproved_lucky_gift()
returns trigger language plpgsql security definer set search_path = ''
as $f$
begin
 if new.diamond_source_type='LUCKY_GIFT' or exists(
   select 1 from public.gift_catalog c where c.id=new.gift_id and c.diamond_source_type='LUCKY_GIFT'
 ) then
   if new.diamond_source_type<>'LUCKY_GIFT' or not exists(
     select 1 from public.gift_catalog c where c.id=new.gift_id and
      c.category_id='luck' and c.diamond_source_type='LUCKY_GIFT' and c.is_active
   ) then raise exception 'Lucky gift classification mismatch' using errcode='42501';end if;
   if not exists (select 1 from phase3.lucky_settings where singleton and enabled)
   then raise exception 'LUCKY_GIFT_DISABLED_BY_OWNER' using errcode='42501';end if;
   if (select coalesce(sum(weight),0) from phase3.lucky_reward_tiers)<>10000
   then raise exception 'LUCKY_GIFT_INVALID_ODDS' using errcode='42501';end if;
 end if;
 return new;
end $f$;
-- Draw happens in the same transaction as the gift, with no wallet bonus.
create or replace function phase3.draw_verified_lucky_award()
returns trigger language plpgsql security definer set search_path = ''
as $f$
declare cfg phase3.lucky_settings%rowtype;
 total_weight integer; roll integer; bytes bytea;
 choice record; points bigint; low bigint;
begin
 if new.diamond_source_type<>'LUCKY_GIFT' then return new;end if;
 if auth.uid() is distinct from new.sender_id then raise exception 'Lucky gift actor mismatch' using errcode='42501';end if;
 -- Prevent concurrent draws from bypassing per-recipient daily caps.
 perform pg_advisory_xact_lock(hashtextextended('lucky:'||new.recipient_id::text,0));
 select * into cfg from phase3.lucky_settings where singleton for share;
 if not found or not cfg.enabled then raise exception 'Lucky rewards are not enabled' using errcode='42501';end if;
 select coalesce(sum(t.weight),0)::integer into total_weight
 from phase3.lucky_reward_tiers t
 where t.max_daily_wins is null or
 (select count(*) from phase3.lucky_awards a where a.recipient_id=new.recipient_id and
    a.reward_tier=t.tier and a.created_at>=(now() at time zone 'Asia/Baghdad')::date at time zone 'Asia/Baghdad')<t.max_daily_wins;
 if total_weight<1 then raise exception 'Lucky daily limits reached';end if;
 -- CSPRNG from gen_random_uuid(), rejection sampling avoids modulo bias.
 loop
  bytes:=decode(substr(replace(gen_random_uuid()::text,'-',''),1,8),'hex');
  low:=(get_byte(bytes,0)::bigint*16777216+
    get_byte(bytes,1)::bigint*65536+get_byte(bytes,2)::bigint*256+get_byte(bytes,3)::bigint);
  exit when low < (4294967296::bigint - (4294967296::bigint % total_weight));
 end loop;
 roll:=(low % total_weight)::integer;
 select t.tier,t.weight,t.multiplier into choice from (
   select z.tier,z.weight,z.multiplier,
    sum(z.weight) over(order by z.sort_order,z.tier) edge
   from phase3.lucky_reward_tiers z
   where z.max_daily_wins is null or
      (select count(*) from phase3.lucky_awards a where a.recipient_id=new.recipient_id and
        a.reward_tier=z.tier and a.created_at>=(now() at time zone 'Asia/Baghdad')::date at time zone 'Asia/Baghdad')<z.max_daily_wins
 ) t where t.edge>roll order by t.edge limit 1;
 if not found then raise exception 'Lucky draw could not be settled';end if;
 if new.amount>9007199254740991/greatest(choice.multiplier-1,1)
 then raise exception 'Lucky points maximum exceeded';end if;
 points:=new.amount*(choice.multiplier-1); -- extra points only, 0 for x1
 insert into phase3.lucky_awards(gift_event_id,sender_id,recipient_id,room_id,gift_id,
 quantity,base_coins,bonus_points,reward_tier,multiplier,odds_weight,rules_version)
 values(new.id,new.sender_id,new.recipient_id,new.room_id,new.gift_id,
 new.quantity,new.amount,points,choice.tier,choice.multiplier,choice.weight,cfg.version);
 return new;
end $f$;
drop trigger if exists tc_verified_lucky_award on public.gift_events;
create trigger tc_verified_lucky_award after insert on public.gift_events
for each row execute function phase3.draw_verified_lucky_award();
-- Return trustworthy draw result on original existing send endpoint, preserving idempotency.
create or replace function phase3.send_gift_checked(
 p_room_id uuid,p_recipient_id uuid,p_gift_id text,p_quantity integer,p_request_id uuid,p_expected_price bigint
) returns jsonb language plpgsql security definer set search_path = ''
as $f$
declare u uuid:=phase3.actor(); actual bigint; prior public.financial_operations%rowtype;
 response jsonb; winner phase3.lucky_awards%rowtype;
begin
 if p_request_id is null then raise exception 'Request ID required';end if;
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if found then
  if prior.operation<>'gift' then raise exception 'Idempotency key conflict';end if;
  if prior.payload<>jsonb_build_object('room',p_room_id,'recipient',p_recipient_id,'gift',p_gift_id,'quantity',p_quantity)
   then raise exception 'Idempotency payload conflict';end if;
  return prior.result;
 end if;
 select price into actual from public.gift_catalog where id=p_gift_id and is_active for share;
 if p_expected_price is null or actual is null or actual<>p_expected_price
 then raise exception 'Price changed; refresh and confirm again';end if;
 response:=phase3.send_gift(p_room_id,p_recipient_id,p_gift_id,p_quantity,p_request_id);
 select * into winner from phase3.lucky_awards where gift_event_id=(response->>'id')::uuid;
 if found then
  response:=response||jsonb_build_object('luckyResult',jsonb_build_object(
   'eventId',winner.event_id,'rewardTier',winner.reward_tier,'multiplier',winner.multiplier,
   'bonusPoints',winner.bonus_points,'baseCoins',winner.base_coins,
   'rulesVersion',winner.rules_version,'currency','LUCKY_POINTS_NON_REDEEMABLE'));
  update public.financial_operations set result=response where id=winner.gift_event_id;
 end if;
 return response;
end $f$;
-- History does not expose other users' awards.
create or replace function phase3.lucky_history(p_limit integer default 25)
returns jsonb language sql security definer set search_path = ''
as $f$
 select coalesce(jsonb_agg(jsonb_build_object('eventId',event_id,'senderId',sender_id,
  'recipientId',recipient_id,'roomId',room_id,'giftId',gift_id,'quantity',quantity,
  'baseCoins',base_coins,'bonusPoints',bonus_points,'rewardTier',reward_tier,
  'multiplier',multiplier,'createdAt',created_at) order by created_at desc),'[]'::jsonb)
 from (select * from phase3.lucky_awards where sender_id=phase3.actor() or recipient_id=phase3.actor()
 order by created_at desc limit greatest(1,least(coalesce(p_limit,25),50))) t
$f$;
revoke all on function phase3.lucky_history(integer) from public,anon;
grant execute on function phase3.lucky_history(integer) to authenticated;
create or replace function public.phase6_lucky_gift_history(p_limit integer default 25)
returns jsonb language sql security invoker set search_path = ''
as $f$ select phase3.lucky_history(p_limit) $f$;
revoke all on function public.phase6_lucky_gift_history(integer) from public,anon;
grant execute on function public.phase6_lucky_gift_history(integer) to authenticated;
-- Owner and explicitly designated main partner may change the policy.
create or replace function phase3.lucky_admin_configure(
 p_enabled boolean, p_rules jsonb, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = ''
as $f$
declare u uuid:=phase3.actor(); old phase3.lucky_config_requests%rowtype;
 body jsonb; result jsonb; weight_total integer; has_safe boolean; item jsonb;
begin
 if not phase3.banner_admin_allowed() then raise exception 'Owner or main partner required' using errcode='42501';end if;
 if p_request_id is null or p_enabled is null or jsonb_typeof(p_rules)<>'array' or
   jsonb_array_length(p_rules) not between 1 and 8 then raise exception 'Provide valid odds and approval';end if;
 body:=jsonb_build_object('enabled',p_enabled,'tiers',p_rules);
 perform pg_advisory_xact_lock(hashtextextended('lucky-policy-update',0));
 select * into old from phase3.lucky_config_requests where actor_id=u and request_id=p_request_id;
 if found then
  if old.payload<>body then raise exception 'Request replay mismatch';end if;
  return old.result;
 end if;
 if exists(select 1 from jsonb_array_elements(p_rules) x
  where jsonb_typeof(x->'rewardTier')<>'string' or
    (x->>'rewardTier') !~ '^[a-z][a-z0-9_]{0,24}$' or
    jsonb_typeof(x->'label')<>'string' or
    length(x->>'label') not between 1 and 70 or
    jsonb_typeof(x->'weight')<>'number' or (x->>'weight') !~ '^[0-9]{1,5}$' or
    (x->>'weight')::integer not between 1 and 10000 or
    jsonb_typeof(x->'multiplier')<>'number' or (x->>'multiplier') !~ '^[0-9]{1,3}$' or
    (x->>'multiplier')::integer not between 1 and 100 or
    (x ? 'maxDailyWins' and x->>'maxDailyWins' is not null and
      ((x->>'maxDailyWins') !~ '^[0-9]{1,5}$' or (x->>'maxDailyWins')::integer not between 1 and 10000))
 ) then raise exception 'Invalid lucky tier and cap';end if;
 select sum((x->>'weight')::integer),
  bool_or((x->>'multiplier')::integer=1 and (not x?'maxDailyWins' or x->>'maxDailyWins' is null))
 into weight_total,has_safe from jsonb_array_elements(p_rules) x;
 if weight_total<>10000 or not coalesce(has_safe,false) then
  raise exception 'Weights must total 10000 and x1 uncapped must remain available';end if;
 if (select count(distinct x->>'rewardTier') from jsonb_array_elements(p_rules) x)
    <>jsonb_array_length(p_rules) then raise exception 'Duplicate reward tiers';end if;
 -- Serialize payouts with config modifications: transaction lock via settings row.
 perform 1 from phase3.lucky_settings where singleton for update;
 delete from phase3.lucky_reward_tiers;
 insert into phase3.lucky_reward_tiers(tier,label,weight,multiplier,max_daily_wins,sort_order)
 select x->>'rewardTier',x->>'label',(x->>'weight')::integer,
   (x->>'multiplier')::integer,(x->>'maxDailyWins')::integer,row_number() over()-1
 from jsonb_array_elements(p_rules) x;
 update phase3.lucky_settings set enabled=p_enabled,version=version+1,updated_at=now() where singleton;
 result:=phase3.lucky_policy_read();
 insert into phase3.lucky_config_requests(actor_id,request_id,payload,result)values(u,p_request_id,body,result);
 insert into public.security_audit(actor_id,action,details)values(u,'lucky_rules_approved',
   jsonb_build_object('requestId',p_request_id,'enabled',p_enabled,'tiers',p_rules));
 return result;
end $f$;
revoke all on function phase3.lucky_admin_configure(boolean,jsonb,uuid) from public,anon;
grant execute on function phase3.lucky_admin_configure(boolean,jsonb,uuid) to authenticated;
create or replace function public.phase6_lucky_gift_configure(
 p_enabled boolean,p_rules jsonb,p_request_id uuid
) returns jsonb language sql security invoker set search_path = ''
as $f$ select phase3.lucky_admin_configure(p_enabled,p_rules,p_request_id) $f$;
revoke all on function public.phase6_lucky_gift_configure(boolean,jsonb,uuid) from public,anon;
grant execute on function public.phase6_lucky_gift_configure(boolean,jsonb,uuid) to authenticated;
-- Live Staging pilot only: nonredeemable lucky points, published odds, no extra wallet payouts.
-- IMPORTANT: Leave inactive by default in every fresh environment, especially production.
-- Only the isolated Staging project was explicitly enabled for pilot verification.
-- Admin Owner/main partner must approve real policy via phase6_lucky_gift_configure before production activation.
