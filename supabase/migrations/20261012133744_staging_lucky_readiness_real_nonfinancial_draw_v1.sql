-- Compatibility readiness RPC reads actual verified, server-configured lucky policy.
-- Pilot odds are not treated as approved cash payouts.
create or replace function public.phase5_lucky_gift_readiness()
returns jsonb language plpgsql security invoker set search_path = ''
as $fn$
declare policy jsonb:=phase3.lucky_policy_read(); active boolean;
begin
 active:=(policy->>'enabled')::boolean;
 return jsonb_build_object(
  'enabled',active,'purchasesAllowed',active,
  'code',case when active then 'STAGING_NONCASH_POINTS_DRAW' else 'LUCKY_GIFT_DISABLED_BY_OWNER' end,
  'approvedOddsPublished',false,
  'oddsAreProvisionalStaging',true,
  'serverDrawAvailable',active,
  'paidPayoutsAllowed',false,
  'bonusCurrency','LUCKY_POINTS_NON_REDEEMABLE',
  'baseGiftDiamondsSettlement','LUCKY_GIFT_BASE_ONLY',
  'tiers',policy->'tiers',
  'rulesVersion',policy->'version');
end $fn$;
revoke all on function public.phase5_lucky_gift_readiness() from public,anon;
grant execute on function public.phase5_lucky_gift_readiness() to authenticated;