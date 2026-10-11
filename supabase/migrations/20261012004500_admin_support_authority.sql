-- Independent Admin: support staff access is verified by DB, not a self-assigned client role.
-- Designated main partner can handle customer service; unassigned Super Admin cannot.
create or replace function phase3.support_handler()
returns boolean language sql security definer set search_path='' as $fn$
 select phase3.is_owner()
 or exists(select 1 from phase3.system_authority s
   where s.singleton and s.main_partner_id=phase3.actor())
 or exists(select 1 from phase3.support_staff p
   where p.user_id=phase3.actor() and p.enabled)
$fn$;
revoke all on function phase3.support_handler() from public,anon;
grant execute on function phase3.support_handler() to authenticated;

create function public.phase6_admin_support_access()
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return jsonb_build_object('canHandle',phase3.support_handler());
end $fn$;
revoke all on function public.phase6_admin_support_access() from public,anon;
grant execute on function public.phase6_admin_support_access() to authenticated;
