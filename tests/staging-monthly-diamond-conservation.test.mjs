import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const migration=read('supabase/migrations/20261012120127_staging_host_month_diamond_conservation_readonly_v1.sql');
const integration=read('supabase/tests/t67_host_month_real_gift_integrity.sql');
test('read-only monthly diamond conservation is Owner/partner-only and never processes financial writes',()=>{
 assert.match(migration,/phase3\.actor\(\)/);
 assert.match(migration,/a\.owner_id=caller or a\.main_partner_id=caller/);
 assert.match(migration,/using errcode='42501'/);
 assert.match(migration,/create function public\.phase7_host_month_diamond_conservation/);
 assert.match(migration,/language plpgsql security invoker set search_path=''/);
 assert.match(migration,/revoke all on function public\.phase7_host_month_diamond_conservation\(date,integer,integer\)\s+from public,anon,authenticated;/);
 assert.match(migration,/grant execute on function public\.phase7_host_month_diamond_conservation\(date,integer,integer\)\s+to authenticated;/);
 const noComments=migration.replace(/--[^\n]*/g,'');
 assert.doesNotMatch(noComments,/\b(?:update|insert|delete|truncate)\s+(?:public|phase3)\./i);
 for(const k of ["'isReadOnly',true","'canPaySalaries',false","'canZeroDiamonds',false","'isReadyForFinalClose',false","'hasPayrollRates',false"])assert(migration.includes(k),k);
});
test('historical earned diamonds never lose value when a host redeems their lots',()=>{
 for(const k of ['public.gift_events','public.agencies','public.diamond_lots',
  'public.diamond_redemption_allocations','public.diamond_redemptions',
  'public.wallets','phase3.host_month_evidence_integrity(p_month)',
  "'earnedDiamonds'","'redeemedDiamondsToDate'","'unredeemedDiamondsNow'",
  "'hostWalletBalanceDiscrepancies'","'redemptionConservationDiscrepancies'",
  "'foreignOwnerRedemptionAllocations'","'snapshotCaptured'"]){
  assert(migration.includes(k),'Missing money conservation invariant '+k);
 }
 assert.match(migration,/lot_amount is distinct from earned/);
 assert.match(migration,/used\+remaining is distinct from lot_amount/);
 assert.match(migration,/r\.fixed_diamonds is distinct from checks\.fixed/);
 assert.match(migration,/r\.lucky_diamonds is distinct from checks\.lucky/);
 assert.match(migration,/w\.diamonds::numeric is distinct from all_lots\.balance/);
});
test('real disposable test exercises redemption at server quote, owner-only audit, tamper and missing lot',()=>{
 for(const k of [
 'phase7_host_month_diamond_conservation(closed_month,0,30)',
 'phase4_preview_redemption(10)',
 'phase4_redeem_diamonds(10',
 "'redeemedDiamondsToDate'<>'10'",
 "'unredeemedDiamondsNow'<>'0'",
 'T67 non-Owner obtained private financial report',
 'T67 tampered gift was not caught',
 'T67 missing lot did not produce complete discrepancy'
 ])assert(integration.includes(k),'Missing integration assertion '+k);
 assert.match(integration,/begin;[\s\S]*rollback;/i);
});
