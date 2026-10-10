begin;
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();sa uuid:=gen_random_uuid();sb uuid:=gen_random_uuid();rid uuid; invitation text; rejected boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(a,a::text||'@test.invalid',now(),false),(b,b::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(sa,a),(sb,b);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'session_id',sa,'aal','aal1')::text,true);
 rid:=public.phase2_room_create('Real SQL room test',true);
 if (select count(*) from public.phase2_room_members(rid))<>1 then raise exception 'Room wrapper failed';end if;
 perform public.phase2_room_take_seat(rid,15);perform public.phase2_room_set_muted(rid,false);perform public.phase2_room_send_message(rid,'Transactional chat test');
 invitation:=public.phase2_room_invite_create(rid);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'session_id',sb,'aal','aal1')::text,true);
 perform public.phase2_room_invite_join(rid,split_part(invitation,':',2));
 if (select count(*) from public.phase2_room_members(rid))<>2 then raise exception 'Private invitation wrapper failed';end if;
 rejected:=false;begin perform public.phase2_room_take_seat(rid,15);exception when others then rejected:=true;end;
 if not rejected then raise exception 'Occupied seat accepted';end if;
 perform public.phase2_room_take_seat(rid,14);perform public.phase2_room_set_muted(rid,false);
 perform public.phase2_room_leave(rid);
 if exists(select 1 from public.room_members where user_id=b) then raise exception 'Leave wrapper failed';end if;
end $$;
rollback;
select 'PASS: authenticated private room create/members/15 seats/mute/chat/invite/join/leave; fixtures rolled back' as result;
