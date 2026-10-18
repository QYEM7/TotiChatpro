import {readFileSync, existsSync} from 'node:fs';
import {join} from 'node:path';

export function assertLegacyClient(root) {
  const manifest = join(root, 'active-client.json');
  if (!existsSync(manifest)) return; // Historical branches predate the manifest.
  const client = JSON.parse(readFileSync(manifest, 'utf8'));
  if (client.framework !== 'capacitor') {
    throw new Error('Legacy web/Capacitor packaging is blocked. Active client: '
      + client.sourceDirectory + ' (' + client.framework + '). Use the Flutter QA workflow; APK builds remain frozen.');
  }
}
