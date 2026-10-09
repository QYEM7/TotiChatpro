import type { CapacitorConfig } from '@capacitor/cli';

// Phase 2 BETA uses a separate Android ID to avoid an install/signing clash
// with old experimental TotiChat APKs. Release application ID is not frozen yet.
const config: CapacitorConfig = {
  appId: 'com.totichat.beta',
  appName: 'TotiChat',
  webDir: 'dist',
  server: { androidScheme: 'https' },
  plugins: {}
};
export default config;
