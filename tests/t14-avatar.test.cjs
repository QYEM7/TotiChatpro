'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const a=fs.readFileSync('app/phase2-auth.js','utf8'),u=fs.readFileSync('app/phase2-ui.js','utf8');
test('T14 avatar upload requires actual user and max 5MB JPG/PNG/WebP',()=>{
 assert(a.includes('file.size>5242880'));
 assert(a.includes("origin+'/storage/v1/object/profile-avatars/'"));
 assert(a.includes("parts?.[1]===userId"));
 assert(a.includes('generation!==requestGeneration'));
 assert(u.includes('selectedAvatar?auth.uploadAvatar(selectedAvatar'));
 assert(u.includes("event.target?.id!=='editAvatarUpload'||!auth.state().signedIn"));
});
