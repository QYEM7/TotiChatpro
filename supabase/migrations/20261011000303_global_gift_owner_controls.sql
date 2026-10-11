-- Staging: owner and designated main partner may manage global verified gift feed.
-- Other super admins and DB personnel cannot change broadcast thresholds/eligibility.
create function phase3.global_gift_owner_controls(
 p_action text,p_enabled boolean default null,p_min_price bigint default null,p_gift_id text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
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
      (p_min_price is null or p_min_price<1 or p_min_price>9007199254740991)) or
      (p_min_price is not null and (p_min_price<1 or p_min_price>9007199254740991)) then
     raise exception 'A valid minimum gift unit price is required';
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
end $$;
revoke all on function phase3.global_gift_owner_controls(text,boolean,bigint,text) from public,anon,authenticated;
grant execute on function phase3.global_gift_owner_controls(text,boolean,bigint,text) to authenticated;
create function public.phase3_global_gift_admin(
 p_action text,p_enabled boolean default null,p_min_price bigint default null,p_gift_id text default null
) returns jsonb language sql security invoker set search_path='' as $$
 select phase3.global_gift_owner_controls(p_action,p_enabled,p_min_price,p_gift_id) $$;
revoke all on function public.phase3_global_gift_admin(text,boolean,bigint,text) from public,anon;
grant execute on function public.phase3_global_gift_admin(text,boolean,bigint,text) to authenticated;
