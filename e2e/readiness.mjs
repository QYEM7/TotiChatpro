import '../scripts/load-local-env.mjs';
export default async function(){
 const required=['TEST_USER1_EMAIL','TEST_USER1_PASSWORD','TEST_USER2_EMAIL','TEST_USER2_PASSWORD','TEST_ROOM_ID'];
 const missing=required.filter(k=>!process.env[k]);if(missing.length)throw Error('BLOCKED real E2E: add '+missing.join(', ')+' to .env.local or CI secrets. No credentials are logged; no mock fallback.');
 if(process.env.TEST_USER1_EMAIL===process.env.TEST_USER2_EMAIL)throw Error('Real E2E requires two separate confirmed accounts');
 for(const k of ['TEST_USER1_EMAIL','TEST_USER2_EMAIL'])if(/@.*\.(invalid|local|test)$/i.test(process.env[k]))throw Error('Real E2E requires deliverable email accounts; example domains are not accepted');
 if(!/^[0-9a-f-]{36}$/i.test(process.env.TEST_ROOM_ID))throw Error('TEST_ROOM_ID must identify an existing authorized room');
}
