import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: '.',
  testMatch: 'reference-fusion-login-*.spec.mjs',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list'], ['json',{outputFile:'test-results/login-browser-results.json'}]],
  outputDir: 'test-results',
  timeout: 45000,
  use: { headless: true, browserName: 'chromium', screenshot: 'off', trace: 'off',
    launchOptions: {args:['--no-sandbox']} }
});
