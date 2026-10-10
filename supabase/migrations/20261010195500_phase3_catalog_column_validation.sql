create or replace function phase3.catalog_write(p_table text,p_action text,p_id text,p_record jsonb,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); body jsonb; prior phase3.admin_requests%rowtype; key_name text; columns_sql text:=''; values_sql text:=''; updates_sql text:=''; answer jsonb;
begin
 perform phase3.require_catalog_admin();
 if p_table is null or p_table not in('gift_categories','gift_catalog','store_catalog','cp_types','recharge_packages','recharge_reward_tiers') or p_action is null or p_action not in('create','update','delete') or p_request_id is null then raise exception 'Invalid catalog operation';end if;
 if p_action<>'create' and (p_id is null or char_length(p_id)>100) then raise exception 'Record ID required';end if;
 if p_action<>'delete' and (p_record is null or jsonb_typeof(p_record)<>'object' or octet_length(p_record::text)>20000 or p_record='{}'::jsonb) then raise exception 'A nonempty record object is required';end if;
 body:=jsonb_build_object('table',p_table,'action',p_action,'id',p_id,'record',p_record);
 select * into prior from phase3.admin_requests where actor_id=u and request_id=p_request_id;
 if found then if prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;end if;
 if (select count(*) from phase3.admin_requests where actor_id=u and created_at>now()-interval '1 minute')>=60 then raise exception 'Rate limit exceeded';end if;
 if p_action<>'delete' then
  for key_name in select jsonb_object_keys(p_record) loop
   if key_name in('created_at','updated_at') or (p_action='update' and key_name='id') or not exists(select 1 from information_schema.columns where table_schema='public' and table_name=p_table and information_schema.columns.column_name=key_name) then raise exception 'Unknown or immutable column: %',key_name;end if;
   columns_sql:=columns_sql||case when columns_sql='' then '' else ',' end||format('%I',key_name);
   values_sql:=values_sql||case when values_sql='' then '' else ',' end||format('v.%I',key_name);
   updates_sql:=updates_sql||case when updates_sql='' then '' else ',' end||format('%I=v.%I',key_name,key_name);
  end loop;
 end if;
 if p_action='create' then execute format('insert into public.%I as target (%s) select %s from jsonb_populate_record(null::public.%I,$1) v returning to_jsonb(target)',p_table,columns_sql,values_sql,p_table) into answer using p_record;
 elsif p_action='update' then execute format('update public.%I as target set %s from jsonb_populate_record(null::public.%I,$1) v where target.id::text=$2 returning to_jsonb(target)',p_table,updates_sql,p_table) into answer using p_record,p_id;
 else execute format('delete from public.%I as target where id::text=$1 returning to_jsonb(target)',p_table) into answer using p_id;end if;
 if answer is null then raise exception 'Record not found';end if;
 insert into phase3.admin_requests(actor_id,request_id,payload,result) values(u,p_request_id,body,answer);
 insert into public.security_audit(actor_id,action,details) values(u,'catalog_'||p_action,jsonb_build_object('table',p_table,'id',answer->>'id','request',p_request_id,'record',answer));
 return answer;
end $$;
