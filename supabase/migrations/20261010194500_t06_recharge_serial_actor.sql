-- T06/T29/T30 forward-only: serialize all authenticated recharge RPC calls per actor.
-- Prevents concurrent requests for one account from racing its 30/min budget
-- or duplicate Owner cash issuance reference. Existing finance math unchanged.
-- ONLY tested in an unlinked database until T49 recovery/staging gates pass.
create or replace function public.phase4_recharge_action(
 p_action text,p_data jsonb,p_request_id uuid
) returns jsonb language plpgsql security invoker set search_path='' as $fn$
declare u uuid:=phase3.actor();
begin
 perform pg_advisory_xact_lock(hashtextextended('totichat-recharge:'||u::text,0));
 return phase3.recharge_action(p_action,p_data,p_request_id);
end $fn$;
comment on function public.phase4_recharge_action(text,jsonb,uuid) is
 'Verified actor transaction serialization before recharge action; no changes to coin conservation or privilege model.';
