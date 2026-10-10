/* Only edits generated dist/app/config.js. No database writes. */
import './load-local-env.mjs';
import {prepareStagingRuntime} from './t03-staging-config.mjs';
const result=await prepareStagingRuntime();
console.log('PASS: staging build configured for isolated project '+result.projectRef+'; private values not printed');
