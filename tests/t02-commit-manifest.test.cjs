'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'..','docs','evidence','t02');
const sha=/^[a-f0-9]{40}$/;
const groups=new Set(['tests_ci_build','fix_performance','ui_visual','docs','feature_integration','merge','other']);
test('T02: 143 unique audited development commits from pinned recovery point',()=>{
 const lines=fs.readFileSync(path.join(root,'phase2-commit-manifest.tsv'),'utf8').trimEnd().split('\n');
 assert.equal(lines[0],'sha\tcommit_timestamp_utc\tgroup\tsubject');
 assert.equal(lines.length,144);
 const data=lines.slice(1).map(s=>s.split('\t'));
 assert.equal(new Set(data.map(row=>row[0])).size,143);
 for(const row of data){assert.equal(row.length,4);assert.match(row[0],sha);assert.match(row[1],/^2026-10-0[9]T|^2026-10-10T/);assert(groups.has(row[2]));assert(row[3].length>0)}
 assert.equal(data[0][0],'95bdba4ea82e99cdb25d65e544c3b32fee4a798e');
 assert.equal(data.at(-1)[0],'b8f20866b70178074859eb53a09bda8f36491401');
});
test('T02: 137 unique changed paths snapshot',()=>{
 const lines=fs.readFileSync(path.join(root,'phase2-changed-files.tsv'),'utf8').trimEnd().split('\n');
 assert.equal(lines[0],'path\tstatus\tadditions\tdeletions\tchanges');
 assert.equal(lines.length,138);
 const rows=lines.slice(1).map(s=>s.split('\t'));
 assert.equal(new Set(rows.map(r=>r[0])).size,137);
 assert(!rows.some(r=>r[0]==='index.html'),'Approved main visual root unexpectedly changed');
 for(const row of rows){assert.equal(row.length,5);for(let i=2;i<5;i++)assert.match(row[i],/^\d+$/)}
});
