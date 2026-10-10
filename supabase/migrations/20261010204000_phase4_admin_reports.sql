alter table phase3.system_authority enable row level security;
alter table phase3.admin_access enable row level security;
alter table phase3.admin_requests enable row level security;
create or replace function phase3.admin_session() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); own boolean:=phase3.is_owner(); access phase3.admin_access%rowtype; partner boolean;
begin
 select * into access from phase3.admin_access where user_id=u;
 select main_partner_id=u into partner from phase3.system_authority where singleton;
 return jsonb_build_object('isOwner',own,'isMainPartner',coalesce(partner,false),'role',case when own then 'owner' else coalesce(access.role,'user') end,'permissions',coalesce(to_jsonb(access.permissions),'[]'::jsonb),
 'canManageCatalogs',own or coalesce(partner,false) or coalesce('catalog.manage'=any(access.permissions),false),
 'canManageHostAgencies',own or coalesce(partner,false),'canManageRechargeAgencies',own or coalesce(partner,false),'canReadReports',own or coalesce(partner,false) or coalesce('reports.read'=any(access.permissions),false));
end $$;

create function phase3.admin_report(p_from timestamptz,p_to timestamptz,p_status text default null,p_offset integer default 0,p_limit integer default 100) returns jsonb language plpgsql security definer set search_path='' as $$
declare rows jsonb; summary jsonb; total bigint;
begin
 if not (phase3.admin_session()->>'canReadReports')::boolean then raise exception 'Reports permission required' using errcode='42501';end if;
 if p_from is null or p_to is null or p_from>=p_to or p_to-p_from>interval '366 days' or p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 100 or (p_status is not null and p_status not in('pending','completed','failed','refunded')) then raise exception 'Invalid report filters';end if;
 select count(*) into total from public.financial_operations where created_at>=p_from and created_at<p_to and (p_status is null or status=p_status);
 select coalesce(jsonb_agg(to_jsonb(r)),'[]') into rows from (select id,actor_id,operation,status,payload,result,created_at from public.financial_operations where created_at>=p_from and created_at<p_to and (p_status is null or status=p_status) order by created_at desc,id limit p_limit offset p_offset) r;
 select jsonb_build_object('users',(select count(*) from auth.users where deleted_at is null),'verified_users',(select count(*) from auth.users where deleted_at is null and email_confirmed_at is not null),'coins',(select coalesce(sum(coins),0) from public.wallets),'diamonds',(select coalesce(sum(diamonds),0) from public.wallets),'gift_count',(select count(*) from public.gift_events where created_at>=p_from and created_at<p_to),'gift_amount',(select coalesce(sum(amount),0) from public.gift_events where created_at>=p_from and created_at<p_to),'relationships',(select count(*) from public.cp_relationships where accepted_at is not null and ended_at is null),'operation_statuses',(select coalesce(jsonb_object_agg(status,n),'{}') from(select status,count(*) n from public.financial_operations where created_at>=p_from and created_at<p_to group by status) s)) into summary;
 return jsonb_build_object('summary',summary,'rows',rows,'total',total,'offset',p_offset,'limit',p_limit,'from',p_from,'to',p_to,'status',p_status);
end $$;
create function public.phase4_admin_report(p_from timestamptz,p_to timestamptz,p_status text default null,p_offset integer default 0,p_limit integer default 100) returns jsonb language sql security invoker set search_path='' as $$ select phase3.admin_report(p_from,p_to,p_status,p_offset,p_limit) $$;
revoke all on function phase3.admin_report(timestamptz,timestamptz,text,integer,integer),public.phase4_admin_report(timestamptz,timestamptz,text,integer,integer) from public,anon,authenticated;
grant execute on function phase3.admin_report(timestamptz,timestamptz,text,integer,integer),public.phase4_admin_report(timestamptz,timestamptz,text,integer,integer) to authenticated;
