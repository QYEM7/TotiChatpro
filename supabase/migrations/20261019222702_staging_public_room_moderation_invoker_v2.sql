-- Applied to Supabase Staging rziaedugbdwefbefcxjt as version 20261019222702.
-- Replaces the authenticated public SECURITY DEFINER moderator wrapper with an invoker.
-- Production / main not altered.
-- Staging security hardening: no SECURITY DEFINER RPC exposed in public.
-- Requires staging_verified_sfu_moderation_relay_acl_v1 first.
-- The private voice-impacting action remains service-role-only.
begin;

create or replace function phase3.room_moderation_nonvoice(
 p_room_id uuid,p_target uuid,p_action text,
 p_request_id uuid,p_reason text default null
) returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 perform phase3.actor();
 -- Strict allowlist: no database-only voice-affecting action can reach here.
 if p_action is null or
    p_action not in ('allow_mic','grant_moderator','revoke_moderator','unban')
 then
    raise exception 'VOICE_RELAY_REQUIRED' using errcode='42501';
 end if;
 return phase3.room_moderation_action(
   p_room_id,p_target,p_action,p_request_id,p_reason
 );
end $body$;

revoke all on function phase3.room_moderation_nonvoice(
 uuid,uuid,text,uuid,text
) from public,anon,authenticated;
grant execute on function phase3.room_moderation_nonvoice(
 uuid,uuid,text,uuid,text
) to authenticated;

-- Replace the prior SECURITY DEFINER public wrapper with an invoker.
-- The call then uses only the purpose-limited *private* definer above.
create or replace function public.phase2_room_moderate(
 p_room_id uuid,p_target uuid,p_action text,
 p_request_id uuid,p_reason text default null
) returns jsonb language sql security invoker set search_path='' as $body$
  select phase3.room_moderation_nonvoice(
   p_room_id,p_target,p_action,p_request_id,p_reason
  )
$body$;

revoke all on function public.phase2_room_moderate(
 uuid,uuid,text,uuid,text
) from public,anon;
grant execute on function public.phase2_room_moderate(
 uuid,uuid,text,uuid,text
) to authenticated;
-- Sensitive internal function NEVER regains direct authenticated EXECUTE.
revoke all on function phase3.room_moderation_action(
 uuid,uuid,text,uuid,text
) from public,anon,authenticated;

commit;
