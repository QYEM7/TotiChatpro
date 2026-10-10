create or replace function phase3.catalog_list(p_table text,p_offset integer default 0,p_limit integer default 100) returns jsonb language plpgsql security definer set search_path='' as $$
declare rows jsonb;total bigint;columns_meta jsonb;
begin
 perform phase3.require_catalog_admin();
 if p_table is null or p_table not in('gift_categories','gift_catalog','store_catalog','cp_types','recharge_packages','recharge_reward_tiers') or p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid catalog query';end if;
 execute format('select coalesce(jsonb_agg(to_jsonb(r)),''[]''::jsonb) from (select * from public.%I order by id limit $1 offset $2) r',p_table) into rows using p_limit,p_offset;
 execute format('select count(*) from public.%I',p_table) into total;
 select jsonb_agg(jsonb_build_object('name',column_name,'type',data_type,'nullable',is_nullable='YES','hasDefault',column_default is not null,'defaultTrue',column_default='true') order by ordinal_position) into columns_meta from information_schema.columns where table_schema='public' and table_name=p_table and column_name not in('created_at','updated_at');
 return jsonb_build_object('rows',rows,'total',total,'offset',p_offset,'limit',p_limit,'columns',columns_meta);
end $$;
