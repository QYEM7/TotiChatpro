-- Applied to Supabase Staging rziaedugbdwefbefcxjt as version 20261019222504.
-- Coordinated with phase2-voice-moderate Edge Function version 2 (JWT verification on).
-- Production / main not altered by this migration.
-- STAGING-ONLY CANDIDATE. NOT YET APPLIED TO ANY DATABASE.
-- Promote via "supabase migration new" after independent review and test.
-- Deploy SQL and matching Edge function together, with a short maintenance gate.
-- The existing security-definer phase3.room_moderation_action enforces the
-- verified user/session, room role, owner/mod hierarchy, audit and idempotency.

begin;

-- All existing public clients retain permission for non-voice-impacting
-- actions such as allow_mic, grant_moderator, revoke_moderator and unban.
-- The DB-only bypass for mute/kick/ban/release_seat is closed.
create or replace function public.phase2_room_moderate(
 p_room_id uuid, p_target uuid, p_action text,
 p_request_id uuid, p_reason text default null
)
returns jsonb language plpgsql security definer set search_path='' as $fn$
begin
  perform phase3.actor();
  if p_action in ('mute','kick','ban','release_seat') then
    raise exception 'VOICE_RELAY_REQUIRED' using errcode='42501';
  end if;
  return phase3.room_moderation_action(
    p_room_id,p_target,p_action,p_request_id,p_reason
  );
end $fn$;

-- Server-only endpoint. This function intentionally accepts *verified*
-- JWT claims only from a trusted service-role Edge function. The Edge
-- function must run auth.getUser(jwt) and phase4_verified_session() using
-- that SAME user token before this RPC. The database rechecks actor()
-- and the current session against auth.sessions, preserving role checks.
create or replace function public.phase2_room_moderate_voice_relay(
 p_verified_user_claims jsonb,
 p_room_id uuid, p_target uuid, p_action text,
 p_request_id uuid, p_reason text default null
)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
 original_role text := auth.jwt()->>'role';
begin
  if original_role is distinct from 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_verified_user_claims is null
    or p_verified_user_claims->>'role' is distinct from 'authenticated'
    or coalesce(p_verified_user_claims->>'sub','') !~*
       '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or coalesce(p_verified_user_claims->>'session_id','') !~*
       '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or p_action is null
    or p_action not in ('mute','kick','ban','release_seat')
  then
    raise exception 'INVALID_VOICE_RELAY_REQUEST' using errcode='42501';
  end if;

  -- Local transaction scope only; no permanent elevated session.
  -- The session, MFA, and permissions are revalidated in phase3.actor().
  perform pg_catalog.set_config(
    'request.jwt.claims',p_verified_user_claims::text,true
  );
  perform phase3.actor();
  return phase3.room_moderation_action(
    p_room_id,p_target,p_action,p_request_id,p_reason
  );
end $fn$;

-- No direct access to the sensitive database mutation function:
-- both public API wrappers are SECURITY DEFINER with actor() checks.
revoke all on function phase3.room_moderation_action(
 uuid,uuid,text,uuid,text
) from public,anon,authenticated;
revoke all on function public.phase2_room_moderate(
 uuid,uuid,text,uuid,text
) from public,anon;
grant execute on function public.phase2_room_moderate(
 uuid,uuid,text,uuid,text
) to authenticated;

-- New functions default to PUBLIC EXECUTE: revoke BEFORE enabling.
revoke all on function public.phase2_room_moderate_voice_relay(
 jsonb,uuid,uuid,text,uuid,text
) from public,anon,authenticated;
grant execute on function public.phase2_room_moderate_voice_relay(
 jsonb,uuid,uuid,text,uuid,text
) to service_role;

commit;
