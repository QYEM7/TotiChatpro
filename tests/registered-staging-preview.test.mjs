import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {checkedStagingConfig,EXPECTED_STAGING_REF} from '../scripts/build-registered-staging-preview.mjs';
import {stagingFromEnv} from '../scripts/t03-staging-config.mjs';
const cfg=JSON.parse(readFileSync(new URL('../docs/preview-public-backend.json',import.meta.url),'utf8'));
test('staging is not production and only stores a public API key',()=>{
 const env=checkedStagingConfig(cfg);
 assert.equal(stagingFromEnv(env).projectRef,EXPECTED_STAGING_REF);
 assert.equal(cfg.supabaseUrl,'https://'+EXPECTED_STAGING_REF+'.supabase.co');
 assert(!JSON.stringify(cfg).includes('sqedsnyvjblvbjbizcay'));
 assert(!JSON.stringify(cfg).includes('service_role'));
 assert(!JSON.stringify(cfg).includes('sb_secret_'));
 assert(/^sb_publishable_/.test(cfg.publishableKey));
});
test('cannot silently substitute production or different projects',()=>{
 assert.throws(()=>checkedStagingConfig({...cfg,supabaseUrl:'https://sqedsnyvjblvbjbizcay.supabase.co'}));
 assert.throws(()=>checkedStagingConfig({...cfg,supabaseUrl:'https://bfadhdnudmsggylunhlh.supabase.co'}));
 assert.throws(()=>checkedStagingConfig({...cfg,publishableKey:'sb_secret_fake'}));
 assert.throws(()=>checkedStagingConfig({...cfg,project:'TotiChatpro'}));
});
