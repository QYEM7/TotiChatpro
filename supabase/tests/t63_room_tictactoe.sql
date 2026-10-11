-- T63 real state-machine local PostgreSQL. All user/room/game rows ROLLBACK.
begin;
do $ttt$
declare x uuid:=gen_random_uuid();o uuid:=gen_random_uuid();outsider uuid:=gen_random_uuid();
 sx uuid:=gen_random_uuid();so uuid:=gen_random_uuid();sz uuid:=gen_random_uuid();
 rid uuid:=gen_random_uuid();k uuid:=gen_random_uuid();ret jsonb;msg jsonb;failed boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
  (x,x::text||'@test.invalid',now(),false),
  (o,o::text||'@test.invalid',now(),false),
  (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sx,x),(so,o),(sz,outsider);
 insert into public.rooms(id,owner_id,title,is_private) values
  (rid,x,'T63 isolated real chess-free room',false);
 insert into public.room_members(room_id,user_id) values(rid,x),(rid,o);
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',outsider,'session_id',sz,'aal','aal1')::text,true);
 failed:=false;
 begin perform public.phase5_room_game_state(rid);
 exception when insufficient_privilege then failed:=true;end;
 if not failed then raise exception 'Non-member viewed private room game';end if;
 failed:=false;
 begin perform public.phase5_room_game_action(rid,'start',null,gen_random_uuid());
 exception when insufficient_privilege then failed:=true;end;
 if not failed then raise exception 'Non-member started room match';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',x,'session_id',sx,'aal','aal1')::text,true);
 ret:=public.phase5_room_game_state(rid);
 if ret->>'hasGame'<>'false' then raise exception 'Fake game was created';end if;
 ret:=public.phase5_room_game_action(rid,'start',null,k);
 if ret->>'status'<>'waiting' or ret->>'playerX'<>x::text or
  ret->>'board'<>'.........' then
  raise exception 'Real match waiting state wrong';end if;
 if public.phase5_room_game_action(rid,'start',null,k)<>ret then
  raise exception 'Start idempotency failed';end if;
 failed:=false;
 begin perform public.phase5_room_game_action(rid,'join',null,k);
 exception when others then failed:=true;end;
 if not failed then raise exception 'Reused request accepted changed action';end if;
 failed:=false;
 begin perform public.phase5_room_game_action(rid,'join',null,gen_random_uuid());
 exception when others then failed:=true;end;
 if not failed then raise exception 'Same user joined own two-person match';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',o,'session_id',so,'aal','aal1')::text,true);
 failed:=false;
 begin perform public.phase5_room_game_action(rid,'move',0,gen_random_uuid());
 exception when others then failed:=true;end;
 if not failed then raise exception 'Lobby permits move before joining';end if;
 ret:=public.phase5_room_game_action(rid,'join',null,gen_random_uuid());
 if ret->>'status'<>'active' or ret->>'playerO'<>o::text then
  raise exception 'Two-member activation failed';end if;
 failed:=false;
 begin perform public.phase5_room_game_action(rid,'move',4,gen_random_uuid());
 exception when others then failed:=true;end;
 if not failed then raise exception 'Out-of-turn O move accepted';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',x,'session_id',sx,'aal','aal1')::text,true);
 ret:=public.phase5_room_game_action(rid,'move',0,gen_random_uuid());
 if ret->>'board'<>'X........' or ret->>'nextMark'<>'O' or
  ret->>'turnNo'<>'1' then raise exception 'First genuine move wrong';end if;
 failed:=false;
 begin perform public.phase5_room_game_action(rid,'move',1,gen_random_uuid());
 exception when others then failed:=true;end;
 if not failed then raise exception 'Same player moved twice';end if;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',o,'session_id',so,'aal','aal1')::text,true);
 perform public.phase5_room_game_action(rid,'move',3,gen_random_uuid());
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',x,'session_id',sx,'aal','aal1')::text,true);
 perform public.phase5_room_game_action(rid,'move',1,gen_random_uuid());
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',o,'session_id',so,'aal','aal1')::text,true);
 perform public.phase5_room_game_action(rid,'move',4,gen_random_uuid());
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',x,'session_id',sx,'aal','aal1')::text,true);
 msg:=public.phase5_room_game_action(rid,'move',2,gen_random_uuid());
 if msg->>'status'<>'won' or msg->>'winnerId'<>x::text or
   msg->>'board'<>'XXXOO....' or msg->>'turnNo'<>'5' then
  raise exception 'Authoritative win rule/board incorrect';end if;
 failed:=false;
 begin perform public.phase5_room_game_action(rid,'move',6,gen_random_uuid());
 exception when others then failed:=true;end;
 if not failed then raise exception 'Game accepted turn after victory';end if;
 ret:=public.phase5_room_game_action(rid,'start',null,gen_random_uuid());
 if ret->>'status'<>'waiting' or ret->>'board'<>'.........' then
  raise exception 'Cannot create fresh real match after victory';end if;
 delete from public.room_members where room_id=rid and user_id=x;
 perform set_config('request.jwt.claims',
  jsonb_build_object('sub',o,'session_id',so,'aal','aal1')::text,true);
 ret:=public.phase5_room_game_state(rid);
 if ret->>'status'<>'cancelled' then
  raise exception 'Departed room player left active lobby';end if;
 if has_table_privilege('authenticated','public.room_game_matches','SELECT,INSERT,UPDATE,DELETE')
  or has_function_privilege('anon','public.phase5_room_game_action(uuid,text,integer,uuid)','EXECUTE')
 then raise exception 'Direct or anonymous game state mutation allowed';end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in('phase5_room_game_action','phase5_room_game_state')
   and p.prosecdef) then raise exception 'Public exposed definer game RPC';end if;
end $ttt$;
rollback;
select 'PASS T63: 3 disposable JWT identities, private room membership, real turns, idempotency, X win, leave cancellation, zero fake games' as result;
