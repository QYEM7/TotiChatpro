-- T59: tested on disposable LOCAL Supabase only, all fixture rows ROLLBACK.
begin;
do $test$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();
 sa uuid:=gen_random_uuid();sb uuid:=gen_random_uuid();sc uuid:=gen_random_uuid();
 key1 uuid:=gen_random_uuid();val jsonb;overview jsonb;items jsonb;denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 (a,a::text||'@test.invalid',now(),false),
 (b,b::text||'@test.invalid',now(),false),
 (c,c::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sa,a),(sb,b),(sc,c);
 update public.profiles set display_name='BetaRealAlpha' where id=a;
 update public.profiles set display_name='BetaRealBravo' where id=b;
 update public.profiles set display_name='BetaRealCharlie' where id=c;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',a,'session_id',sa,'aal','aal1')::text,true);
 overview:=public.phase5_social_overview(a);
 if overview->>'followers'<>'0' or overview->>'friends'<>'0' then
   raise exception 'Fake social count on new account';end if;
 denied:=false;
 begin perform public.phase5_social_follow(a,true,gen_random_uuid());
 exception when others then denied:=true;end;
 if not denied then raise exception 'Self follow allowed';end if;
 val:=public.phase5_social_follow(b,true,key1);
 if val->>'followed'<>'true' then raise exception 'Follow did not persist';end if;
 if public.phase5_social_follow(b,true,key1)<>val then raise exception 'Idempotent follow changed';end if;
 denied:=false;
 begin perform public.phase5_social_follow(c,true,key1);
 exception when others then denied:=true;end;
 if not denied then raise exception 'Conflicting follow key accepted';end if;
 overview:=public.phase5_social_overview(a);
 if overview->>'following'<>'1' or overview->>'friends'<>'0' then
  raise exception 'Follow counters inconsistent';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',b,'session_id',sb,'aal','aal1')::text,true);
 perform public.phase5_social_follow(a,true,gen_random_uuid());
 overview:=public.phase5_social_overview(b);
 if overview->>'following'<>'1' or overview->>'followers'<>'1'
 or overview->>'friends'<>'1' then
  raise exception 'Mutual friendship was not counted';end if;
 items:=public.phase5_social_list('friends',25,null);
 if jsonb_array_length(items->'items')<>1
 or (items->'items'->0->>'user_id')<>a::text then
  raise exception 'Friends list does not contain genuine reciprocal user';end if;
 items:=public.phase5_social_search('BetaRealAl',15);
 if jsonb_array_length(items->'items')<>1
 or (items->'items'->0->>'user_id')<>a::text then
  raise exception 'Authenticated social search failed';end if;
 perform public.phase2_dm_block(a,true);
 if exists(select 1 from public.social_follows where
  (follower_id=a and followed_id=b) or (follower_id=b and followed_id=a)) then
   raise exception 'Blocking did not sever both follow directions';end if;
 denied:=false;
 begin perform public.phase5_social_follow(a,true,gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Blocked target was followed';end if;
 denied:=false;
 begin perform public.phase5_social_overview(a);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Blocked target revealed social graph';end if;
 items:=public.phase5_social_search('BetaRealAl',15);
 if jsonb_array_length(items->'items')<>0 then
  raise exception 'Blocked profile appeared in discovery';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',a,'session_id',sa,'aal','aal1')::text,true);
 overview:=public.phase5_social_overview(a);
 if overview->>'followers'<>'0' or overview->>'following'<>'0'
 or overview->>'friends'<>'0' then
  raise exception 'Unfollow after block did not reset counts';end if;
 if has_table_privilege('authenticated','public.social_follows','SELECT,INSERT,UPDATE,DELETE')
  or has_function_privilege('anon','public.phase5_social_follow(uuid,boolean,uuid)','EXECUTE')
 then raise exception 'Direct client social write/privacy bypass';end if;
end $test$;
rollback;
select 'PASS T59: verified follow, mutual friends, search, block privacy, no fake counts, replay security' as result;
