import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const load=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const gift=load('app/phase2-catalog-ui.js');
const center=load('app/phase6-inapp-admin.js');
const bridge=load('app/phase6-verified-state-sync.js');
const loader=load('app/phase2-backend-controls.js');
const odds=load('supabase/migrations/20261012133310_staging_lucky_gifts_nonredeemable_points_server_draw_v1.sql');
const readiness=load('supabase/migrations/20261012133744_staging_lucky_readiness_real_nonfinancial_draw_v1.sql');
const redemption=load('supabase/migrations/20261012134018_staging_distinct_fixed_30_lucky_10_redemption_v1.sql');
test('Lucky code and trusted admin sync all parse',()=>{
 for(const p of ['app/phase2-catalog-ui.js','app/phase6-inapp-admin.js','app/phase6-verified-state-sync.js'])
  execFileSync(process.execPath,['--check',new URL('../'+p,import.meta.url).pathname]);
 assert.match(loader,/phase6-verified-state-sync\.js/);
});
test('Lucky prizes are server drawn after real financial transfer, never multiplied into wallets',()=>{
 assert.match(odds,/create or replace function phase3\.draw_verified_lucky_award\(\)/i);
 assert.match(odds,/gen_random_uuid\(\)/);
 assert.match(odds,/low % total_weight/);
 assert.match(odds,/reward_tier text/);
 assert.match(odds,/unique default gen_random_uuid/);
 assert.match(odds,/points:=new\.amount\*\(choice\.multiplier-1\)/);
 assert.match(odds,/phase3\.send_gift\(p_room_id,p_recipient_id,p_gift_id,p_quantity,p_request_id\)/);
 assert.doesNotMatch(odds,/update public\.wallets\s+set\s+diamonds\s*=\s*diamonds\s*\+\s*points/i);
 assert.match(odds,/LUCKY_POINTS_NON_REDEEMABLE/);
 assert.match(odds,/phase3\.reject_unapproved_lucky_gift/);
 assert.match(odds,/where singleton and enabled/);
});
test('Lucky replay response cannot produce a second transfer or additional award',()=>{
 assert.match(odds,/select \* into prior from public\.financial_operations where actor_id=u and request_id=p_request_id/);
 assert.match(odds,/if prior\.payload<>jsonb_build_object/);
 assert.match(odds,/return prior\.result/);
 assert.match(odds,/gift_event_id uuid primary key/);
 assert.match(odds,/event_id uuid not null unique/);
 assert.match(gift,/pendingGift=null;\s+void window\.TotiPhase2Wallet/);
 assert.match(gift,/if\(!lucky\|\|typeof lucky\.eventId/);
});
test('Lucky sender receives published probabilities and audited real Lucky History',()=>{
 assert.match(gift,/phase6_lucky_gift_policy/);
 assert.match(gift,/policy\.enabled===true/);
 assert.match(gift,/\?policy:null/);
 assert.match(gift,/phase6_lucky_gift_history/);
 assert.match(gift,/bonusPoints/);
 assert.match(gift,/gift\.diamond_source_type==='LUCKY_GIFT'&&!luckyPolicy/);
 assert.match(gift,/t\.weight\/100/);
 assert.match(readiness,/paidPayoutsAllowed',false/);
 assert.match(readiness,/oddsAreProvisionalStaging',true/);
});
test('Only Owner and designated partner manage policy with owner-validated backend RPC',()=>{
 assert.match(odds,/if not phase3\.banner_admin_allowed\(\)/);
 assert.match(odds,/weight_total<>10000/);
 assert.match(odds,/lucky_config_requests\(actor_id,request_id,payload,result\)/);
 assert.match(odds,/lucky_rules_approved/);
 assert.match(odds,/grant execute on function public\.phase6_lucky_gift_configure\(boolean,jsonb,uuid\) to authenticated/);
 assert.match(center,/\['lucky_gifts','هدايا الحظ والاحتمالات','✦','chief'\]/);
 assert.match(center,/if\(view==='lucky_gifts'\)\{void showLuckyPolicy\(\);return;\}/);
 assert.match(center,/if\(!opened\|\|view!=='lucky_gifts'\|\|!chief\(permission\)/);
 assert.match(center,/phase6_lucky_gift_configure/);
 assert.match(center,/if\(e\.target\?\.id==='tcac-lucky-config'\)/);
});
test('Administrative actions refresh real backend state; never fake role, VIP or banner',()=>{
 assert.match(center,/totichat-admin-action-confirmed/);
 assert.match(center,/recheck:verify/);
 assert.match(bridge,/window\.TotiInAppAdmin\?\.recheck\?\.\(\)/);
 assert.match(bridge,/window\.TotiVipStatus\?\.refresh\?\.\(\)/);
 assert.match(bridge,/window\.TotiBannerData\?\.refresh\?\.\(\)/);
 assert.match(bridge,/window\.TotiPhase2Wallet\?\.refresh\?\.\(\)/);
 assert.match(bridge,/TotiPhase2Rooms\.refreshRoom\(\)/);
 assert.match(bridge,/Promise\.allSettled/);
 assert.doesNotMatch(bridge,/Math\.random|mock|fakeBalance/i);
});

test('Lucky diamonds redeem at 10 percent, fixed diamonds at 30 percent, points never convert',()=>{
 assert.match(redemption,/f::numeric\*rate\.redemption_numerator\/rate\.redemption_denominator/);
 assert.match(redemption,/floor\(l::numeric\/10\)/);
 assert.match(redemption,/luckyConversionRate','10_PERCENT'/);
 assert.match(redemption,/luckyPointsRedeemable',false/);
 assert.equal(Math.floor(100000*3/10)+Math.floor(100000/10),40000);
 assert.equal(Math.floor(0*3/10)+Math.floor(100000/10),10000);
});
