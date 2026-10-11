-- Verified voice-token authorization, safely refresh the ALREADY EXISTING
-- private phase3 implementation and public invoker wrapper. NEVER attempt to
-- move the public function a second time; the canonical migration history
-- already created both functions.
do $qa$
declare private_oid oid:=to_regprocedure('phase3.phase2_voice_token_preflight(uuid)');
begin
 if private_oid is null then
  raise exception 'Private voice token authorization missing; migration ordering broken';
 end if;
 if not (select p.prosecdef from pg_proc p where p.oid=private_oid) then
  raise exception 'Private voice token authorization no longer privileged';
 end if;
end $qa$;

revoke all on function phase3.phase2_voice_token_preflight(uuid) from public,anon;
grant execute on function phase3.phase2_voice_token_preflight(uuid) to authenticated;

-- The exposed function remains SECURITY INVOKER and checks:
-- - verified, nonbanned Auth user and a real unrevoked Auth session
-- - configured MFA/AAL2 through phase3.actor()
-- - real room membership, actual mic seat/mute, and rate budget via private RPC
create or replace function public.phase2_voice_token_preflight(p_room_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return phase3.phase2_voice_token_preflight(p_room_id);
end $fn$;
revoke all on function public.phase2_voice_token_preflight(uuid) from public,anon;
grant execute on function public.phase2_voice_token_preflight(uuid) to authenticated;

comment on function public.phase2_voice_token_preflight(uuid) is
 'Voice-token preflight requires verified active auth session, account validity, MFA if enabled, live room membership and current microphone authorization. Not proof of LiveKit SFU participant revocation.';
