-- Forward-only Staging security hardening after backend room moderation.
-- Keep the private, owner-checked implementation with SECURITY DEFINER in phase3
-- and expose only a session-verified SECURITY INVOKER public API wrapper.
-- Neither roles nor published room data or VIP/financial tables are changed.
alter function public.phase2_room_moderation_state(uuid) set schema phase3;
revoke all on function phase3.phase2_room_moderation_state(uuid) from public,anon;
grant execute on function phase3.phase2_room_moderation_state(uuid) to authenticated;

create function public.phase2_room_moderation_state(p_room_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.phase2_room_moderation_state(p_room_id);
end $fn$;
revoke all on function public.phase2_room_moderation_state(uuid) from public,anon;
grant execute on function public.phase2_room_moderation_state(uuid) to authenticated;

-- Foreign-key cascade from rooms must not scan the complete moderation ledger.
create index tc_room_moderation_requests_room
 on phase3.room_moderation_requests(room_id);
