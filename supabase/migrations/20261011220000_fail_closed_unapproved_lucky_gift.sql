-- T65 CRITICAL FAIL-CLOSED: current "LUCKY_GIFT" catalog has no approved
-- published odds, secure RNG draw, independent payout ledger or audit.
-- Existing phase3.send_gift credits a FIXED amount even for LUCKY_GIFT.
-- Until a compliant Owner-approved payout engine is deployed, REFUSE those
-- transactions transactionally before the gift row is committed. The earlier
-- debit in send_gift therefore ROLLS BACK with this trigger exception.
create function phase3.reject_unapproved_lucky_gift()
returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 if new.diamond_source_type='LUCKY_GIFT'
  or exists(select 1 from public.gift_catalog c
    where c.id=new.gift_id and c.diamond_source_type='LUCKY_GIFT')
 then
  raise exception 'LUCKY_GIFT_PENDING_RULEBOOK' using errcode='42501',
   detail='Lucky gift payout odds are not yet approved and cannot be represented as a fixed payment';
 end if;
 return new;
end $fn$;
revoke all on function phase3.reject_unapproved_lucky_gift() from public,anon,authenticated;
create trigger tc_reject_unapproved_lucky_gifts
 before insert on public.gift_events
 for each row execute function phase3.reject_unapproved_lucky_gift();

-- This informational RPC cannot mint, purchase, configure or award coins.
create function public.phase5_lucky_gift_readiness()
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin
 perform phase3.actor();
 return jsonb_build_object('enabled',false,'purchasesAllowed',false,
  'code','LUCKY_GIFT_PENDING_RULEBOOK','approvedOddsPublished',false,
  'serverDrawAvailable',false,'paidPayoutsAllowed',false);
end $fn$;
revoke all on function public.phase5_lucky_gift_readiness() from public,anon;
grant execute on function public.phase5_lucky_gift_readiness() to authenticated;
comment on function phase3.reject_unapproved_lucky_gift() is
 'Mandatory safety hold: block LUCKY_GIFT until approved published probabilities and transactional random draws exist.';
