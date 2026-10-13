import {defineConfig} from '@playwright/test';
export default defineConfig({
 testDir:'.',
 testMatch:'reference-fusion-home-browser.spec.mjs',
 fullyParallel:false,
 workers:1,
 retries:0,
 reporter:[['list'],['json',{outputFile:'test-results/home-results.json'}]],
 outputDir:'test-results',
 timeout:45000,
 use:{headless:true,browserName:'chromium',launchOptions:{args:['--no-sandbox']}}
});
