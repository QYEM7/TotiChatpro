-- Verified voice-token authorization: share the same active Auth-session,
-- account suspension and MFA checks as financial and room-administration RPCs.
-- Preserve the existing 20/minute database budget, microphone/seat rules,
-- and the unchanged public RPC signature used by deployed Edge voice token.
alter function public.phase2_voice_token_preflight(uuid) set schema phase3;
revoke all on function phase3.phase2_voice_token_preflight(uuid) from public,anon;
grant execute on function phase3.phase2_voice_token_preflight(uuid) to authenticated;

create function public.phase2_voice_token_preflight(p_room_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.phase2_voice_token_preflight(p_room_id);
end $fn$;
revoke all on function public.phase2_voice_token_preflight(uuid) from public,anon;
grant execute on function public.phase2_voice_token_preflight(uuid) to authenticated;

comment on function public.phase2_voice_token_preflight(uuid) is
 'Voice-token preflight requires validated active auth session, MFA if enabled, live room membership and current microphone seat/authorization. Not an SFU transport revocation proof.';
