begin;
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();sa uuid:=gen_random_uuid();sb uuid:=gen_random_uuid();sc uuid:=gen_random_uuid();r uuid:=gen_random_uuid();id uuid:=gen_random_uuid();path text;res jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(a,a::text||'@test.invalid',now(),false),(b,b::text||'@test.invalid',now(),false),(c,c::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sa,a),(sb,b),(sc,c);insert into public.rooms(id,owner_id,title) values(r,a,'QA voice messages');insert into public.room_members(room_id,user_id) values(r,a),(r,b);
 path:=a::text||'/'||r::text||'/'||id::text||'.webm';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sa,'aal','aal1')::text,true);
 if not phase3.voice_object_access(path,'write') then raise exception 'Owner member cannot upload';end if;
 denied:=false;begin perform public.phase4_voice_message('create',id,r,path,'audio/webm',10,1000);exception when others then denied:=true;end;if not denied then raise exception 'Missing upload accepted';end if;
 -- Metadata fixture exists only inside this rollback; no physical fake audio is uploaded.
 insert into storage.objects(bucket_id,name,metadata) values('voice-messages',path,'{"size":10,"mimetype":"audio/webm"}');
 res:=public.phase4_voice_message('create',id,r,path,'audio/webm',10,1000);
 if public.phase4_voice_message('create',id,r,path,'audio/webm',10,1000)<>res then raise exception 'Duplicate voice id changed';end if;
 denied:=false;begin perform public.phase4_voice_message('create',id,r,path,'audio/webm',10,1001);exception when others then denied:=true;end;if not denied then raise exception 'Voice retry content conflict accepted';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'session_id',sb,'aal','aal1')::text,true);
 if not phase3.voice_object_access(path,'read') or phase3.voice_object_access(path,'write') or phase3.voice_object_access(path,'delete') then raise exception 'Recipient storage access incorrect';end if;
 if jsonb_array_length(public.phase4_voice_messages(r))<>1 then raise exception 'Room audio missing';end if;
 denied:=false;begin perform public.phase4_voice_message('delete',id);exception when insufficient_privilege then denied:=true;end;if not denied then raise exception 'Recipient deleted sender audio';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'session_id',sc,'aal','aal1')::text,true);
 if phase3.voice_object_access(path,'read') or phase3.voice_object_access(path,'write') then raise exception 'Nonmember accessed audio';end if;
 denied:=false;begin perform public.phase4_voice_messages(r);exception when insufficient_privilege then denied:=true;end;if not denied then raise exception 'Nonmember listed audio';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sa,'aal','aal1')::text,true);perform public.phase4_voice_message('delete',id);perform public.phase4_voice_message('delete',id);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'session_id',sb,'aal','aal1')::text,true);
 if phase3.voice_object_access(path,'read') or jsonb_array_length(public.phase4_voice_messages(r))<>0 then raise exception 'Deleted audio exposed';end if;
end $$;
rollback;
select 'PASS: private voice metadata, membership/ownership gates, upload validation, retry conflict, deletion privacy; metadata fixtures rolled back, actual recording/playback E2E not asserted' as result;
