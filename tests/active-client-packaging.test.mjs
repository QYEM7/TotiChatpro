import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, writeFileSync, rmSync, readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {assertLegacyClient} from '../scripts/assert-legacy-client.mjs';

for (const [name, data, blocked] of [
  ['Flutter is rejected', '{"framework":"flutter","sourceDirectory":"flutter_app"}', true],
  ['unknown client is rejected', '{"framework":"unknown"}', true],
  ['malformed manifest fails closed', '{', true],
  ['explicit historical Capacitor is supported', '{"framework":"capacitor"}', false],
  ['historical branch without manifest is supported', null, false],
]) test(name, () => {
  const root = mkdtempSync(join(tmpdir(), 'totichat-client-'));
  try {
    if (data !== null) writeFileSync(join(root, 'active-client.json'), data);
    if (blocked) assert.throws(() => assertLegacyClient(root));
    else assert.doesNotThrow(() => assertLegacyClient(root));
  } finally { rmSync(root, {recursive:true, force:true}); }
});

test('real legacy build exits before loading bundler or packaging output', () => {
  const root = new URL('../', import.meta.url);
  const result = spawnSync(process.execPath, ['scripts/build-reborn-web.mjs'], {cwd:root, encoding:'utf8'});
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Legacy web\/Capacitor packaging is blocked/);
  assert.doesNotMatch(result.stderr, /Cannot find package/);
  const source = readFileSync(new URL('../scripts/build-reborn-web.mjs', import.meta.url), 'utf8');
  assert.ok(source.indexOf('assertLegacyClient(root)') < source.indexOf('await rm(output'));
});
