-- TotiChat STAGING only. Visible support needs one real settled 7,000+ coin gift
-- with matching completed financial operation and sender/recipient ledger entries.
begin;
update public.gift_announcement_settings set min_gift_price=7000, enabled=true,
 updated_at=now() where singleton=true;
-- Existing active gift catalog items are eligible, not fictional sends or transactions.
update public.gift_catalog set global_announcement_enabled=true
 where is_active=true and global_announcement_enabled=false;
alter table public.gift_announcement_settings
 add constraint tc_gift_strips_floor_7000 check(min_gift_price is null or min_gift_price>=7000);
alter table public.gift_global_announcements
 add constraint tc_confirmed_support_only_floor_7000 check(total_coins>=7000);
-- Both Owner and service-role configuration paths keep this floor.
CREATE OR REPLACE FUNCTION phase3.global_gift_owner_controls(p_action text, p_enabled boolean DEFAULT NULL::boolean, p_min_price bigint DEFAULT NULL::bigint, p_gift_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=phase3.actor(); authority jsonb:=phase3.admin_session();
 cfg public.gift_announcement_settings%rowtype; items jsonb;
begin
 if not (coalesce((authority->>'isOwner')::boolean,false) or
         coalesce((authority->>'isMainPartner')::boolean,false)) then
   raise exception 'Owner or designated main partner required' using errcode='42501';
 end if;
 if p_action not in ('read','configure','gift_flag') then
   raise exception 'Invalid gift announcement action';
 end if;
 if p_action='configure' then
   if p_enabled is null or (p_enabled and
      (p_min_price is null or p_min_price<7000 or p_min_price>9007199254740991)) or
      (p_min_price is not null and (p_min_price<7000 or p_min_price>9007199254740991)) then
     raise exception 'Minimum verified support is 7000 total coins';
   end if;
   update public.gift_announcement_settings set enabled=p_enabled,
    min_gift_price=coalesce(p_min_price,min_gift_price),updated_by=actor,
    updated_at=now() where singleton=true returning * into cfg;
   if not found then raise exception 'Configuration unavailable';end if;
   insert into public.security_audit(actor_id,action,details)
    values(actor,'global_gift_config',jsonb_build_object('enabled',cfg.enabled,'minPrice',cfg.min_gift_price));
 elsif p_action='gift_flag' then
   if p_gift_id is null or p_enabled is null then raise exception 'Invalid gift option';end if;
   update public.gift_catalog set global_announcement_enabled=p_enabled
   where id=p_gift_id and is_active;
   if not found then raise exception 'Gift unavailable';end if;
   insert into public.security_audit(actor_id,action,details)
    values(actor,'global_gift_eligibility',jsonb_build_object('gift',p_gift_id,'enabled',p_enabled));
 end if;
 select * into cfg from public.gift_announcement_settings where singleton=true;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',id,'name',name,'price',price,'active',is_active,
  'global',global_announcement_enabled) order by price), '[]'::jsonb)
 into items from public.gift_catalog where is_active;
 return jsonb_build_object('enabled',cfg.enabled,'minPrice',cfg.min_gift_price,
   'updatedAt',cfg.updated_at,'gifts',items);
end $function$
;
CREATE OR REPLACE FUNCTION public.phase3_set_gift_global_threshold(p_enabled boolean, p_min_gift_price bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if p_enabled is null or (p_enabled and
  (p_min_gift_price is null or p_min_gift_price<7000 or p_min_gift_price>9007199254740991)) then
  raise exception 'Invalid global announcement settings';
 end if;
 update public.gift_announcement_settings set
  enabled=p_enabled,
  min_gift_price=case when p_min_gift_price is null then min_gift_price else p_min_gift_price end,
  updated_at=now(),
  updated_by=auth.uid()
 where singleton=true;
 if not found then raise exception 'Announcement configuration unavailable';end if;
 return true;
end $function$
;
-- Existing DEFERRABLE INITIALLY DEFERRED trigger stays; updated definition below.
CREATE OR REPLACE FUNCTION public.phase3_gift_announce_verified()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare cfg public.gift_announcement_settings%rowtype; g public.gift_catalog%rowtype;
 sname text; rname text;
begin
 if not exists(select 1 from public.financial_operations op
  where op.id=new.id and op.operation='gift' and op.status='completed') then
   return new;
 end if;
 -- Prove the sender was debited for exactly this committed operation.
 if not exists(select 1 from public.wallet_ledger sender_ledger
  where sender_ledger.transaction_id=new.id and sender_ledger.user_id=new.sender_id
   and sender_ledger.kind='gift_sent' and sender_ledger.currency='coins'
   and sender_ledger.amount_change=-new.amount) then
   return new;
 end if;
 -- Prove the recipient was actually credited for exactly this operation.
 if not exists(select 1 from public.wallet_ledger recipient_ledger
  where recipient_ledger.transaction_id=new.id and recipient_ledger.user_id=new.recipient_id
   and recipient_ledger.kind='gift_received' and recipient_ledger.currency='diamonds'
   and recipient_ledger.amount_change=new.amount) then
   return new;
 end if;
 select * into cfg from public.gift_announcement_settings where singleton=true;
 if not found or not cfg.enabled or cfg.min_gift_price is null or new.amount < greatest(7000::bigint,cfg.min_gift_price) then return new;end if;
 select * into g from public.gift_catalog where id=new.gift_id;
 if not found or not g.is_active or not g.global_announcement_enabled then
  return new;
 end if;
 select display_name into sname from public.profiles where id=new.sender_id;
 select display_name into rname from public.profiles where id=new.recipient_id;
 insert into public.gift_global_announcements(
  id,room_id,sender_id,recipient_id,gift_id,gift_name,gift_icon,sender_name,
  recipient_name,quantity,unit_price,total_coins,created_at
 ) values(
  new.id,new.room_id,new.sender_id,new.recipient_id,new.gift_id,
  g.name,g.icon,coalesce(sname,'مستخدم'),coalesce(rname,'مستخدم'),
  new.quantity,g.price,new.amount,new.created_at
 ) on conflict(id) do nothing;
 return new;
end $function$
;
commit;