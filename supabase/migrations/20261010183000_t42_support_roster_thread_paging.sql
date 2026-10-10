-- T42 support staff roster and bounded ticket paging; forward-only after 20261010171000.
-- This file is not applied to production; CI replays on disposable, unlinked Supabase.
create function public.phase5_support_staff_list(
 p_offset integer default 0,p_limit integer default 30
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=phase3.actor(); total bigint; staff_rows jsonb;
begin
 if not phase3.is_owner() then
   raise exception 'Owner alone may view support staff' using errcode='42501';
 end if;
 if p_offset is null or p_offset<0 or p_offset>100000
    or p_limit is null or p_limit<1 or p_limit>50 then
   raise exception 'Invalid staff pagination';
 end if;
 select count(*) into total from phase3.support_staff;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into staff_rows from (
  select user_id,enabled,granted_by,updated_at from phase3.support_staff
  order by enabled desc,updated_at desc,user_id limit p_limit offset p_offset
 )x;
 return jsonb_build_object('rows',staff_rows,'total',total);
end $fn$;

create function public.phase5_support_thread_page(
 p_ticket_id uuid,p_offset integer default 0,p_limit integer default 30
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=phase3.actor();staff boolean;t phase3.support_tickets%rowtype;
 messages jsonb;total bigint;
begin
 staff:=phase3.is_owner()
   or exists(select 1 from phase3.system_authority a where a.singleton and a.main_partner_id=u)
   or exists(select 1 from phase3.support_staff s where s.user_id=u and s.enabled);
 if p_ticket_id is null then raise exception 'Ticket required';end if;
 if p_offset is null or p_offset<0 or p_offset>100000
    or p_limit is null or p_limit<1 or p_limit>50 then
   raise exception 'Invalid message pagination';
 end if;
 select * into t from phase3.support_tickets where id=p_ticket_id;
 if not found or (t.creator_id<>u and not staff) then
   raise exception 'Ticket not found' using errcode='42501';
 end if;
 select count(*) into total from phase3.support_messages m where m.ticket_id=t.id;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at,x.id),'[]'::jsonb)
 into messages from (
    select id,author_id,body,created_at from phase3.support_messages
    where ticket_id=t.id order by created_at desc,id desc limit p_limit offset p_offset
 )x;
 return jsonb_build_object(
  'ticket',jsonb_build_object('id',t.id,'creator_id',t.creator_id,
   'category',t.category,'subject',t.subject,'status',t.status,
   'assigned_to',t.assigned_to,'created_at',t.created_at,'updated_at',t.updated_at),
  'messages',messages,'total',total,'offset',p_offset,'limit',p_limit,
  'canHandle',staff
 );
end $fn$;

revoke all on function public.phase5_support_staff_list(integer,integer),
  public.phase5_support_thread_page(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.phase5_support_staff_list(integer,integer),
  public.phase5_support_thread_page(uuid,integer,integer) to authenticated;
comment on function public.phase5_support_staff_list(integer,integer) is
 'Owner-only support staff roster; independent of agency and wallet administration.';
comment on function public.phase5_support_thread_page(uuid,integer,integer) is
 'Newest support messages first, bounded page and explicit creator/staff server authorization.';
