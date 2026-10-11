-- Local-only disposable database acceptance: all fixture writes ROLLBACK.
begin;
do $qa$
declare
 own uuid:=gen_random_uuid(); mod_id uuid:=gen_random_uuid();
 guest uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
 own_sid uuid:=gen_random_uuid(); mod_sid uuid:=gen_random_uuid();
 guest_sid uuid:=gen_random_uuid(); outside_sid uuid:=gen_random_uuid();
 rid uuid; private_id uuid; key_id uuid:=gen_random_uuid();
 invite text; reply jsonb; denied boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(own,own::text||'@test.invalid',now(),false),
       (mod_id,mod_id::text||'@test.invalid',now(),false),
       (guest,guest::text||'@test.invalid',now(),false),
       (outsider,outsider::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values
 (own_sid,own),(mod_sid,mod_id),(guest_sid,guest),(outside_sid,outsider);
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',own_sid,'aal','aal1')::text,true);
 rid:=public.phase2_room_create('Moderation integration',false);
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',guest,'session_id',guest_sid,'aal','aal1')::text,true);
 perform public.phase2_room_join(rid);
 perform public.phase2_room_take_seat(rid,3);
 perform public.phase2_room_set_muted(rid,false);
 denied:=false;
 begin perform public.phase2_room_moderate(rid,mod_id,'grant_moderator',gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Ordinary member can self-create moderator';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',mod_id,'session_id',mod_sid,'aal','aal1')::text,true);
 perform public.phase2_room_join(rid);
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',own_sid,'aal','aal1')::text,true);
 perform public.phase2_room_moderate(rid,mod_id,'grant_moderator',gen_random_uuid());
 if (select count(*) from public.room_moderators where room_id=rid and user_id=mod_id)<>1
 then raise exception 'Owner did not grant moderator';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',mod_id,'session_id',mod_sid,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase2_room_moderate(rid,guest,'ban',gen_random_uuid(),'Documented malicious behavior');
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Moderator illegally issued a ban';end if;
 perform public.phase2_room_moderate(rid,guest,'mute',gen_random_uuid());
 if not (select is_muted and moderation_muted from public.room_members where user_id=guest)
 then raise exception 'Moderator failed to enforce persistent mute';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',guest,'session_id',guest_sid,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase2_room_set_muted(rid,false);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Muted member bypassed moderator with self-service unmute';end if;
 -- Leaving and rejoining cannot erase a persistent moderator restriction.
 perform public.phase2_room_leave(rid);
 perform public.phase2_room_join(rid);
 perform public.phase2_room_take_seat(rid,3);
 if not (select moderation_muted from public.room_members where user_id=guest) then
   raise exception 'Moderator mute disappeared after rejoin';end if;
 denied:=false;
 begin perform public.phase2_room_set_muted(rid,false);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Rejoined member bypassed persisted mute';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',mod_id,'session_id',mod_sid,'aal','aal1')::text,true);
 perform public.phase2_room_moderate(rid,guest,'allow_mic',gen_random_uuid());
 if (select moderation_muted from public.room_members where user_id=guest)
 then raise exception 'Moderator unmute permission was not released';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',guest,'session_id',guest_sid,'aal','aal1')::text,true);
 perform public.phase2_room_set_muted(rid,false);
 if (select is_muted from public.room_members where user_id=guest)
 then raise exception 'Member cannot unmute after moderator clears restriction';end if;
 -- Hierarchy: only the room Owner may revoke a mute that the Owner imposed.
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',own_sid,'aal','aal1')::text,true);
 perform public.phase2_room_moderate(rid,guest,'mute',gen_random_uuid());
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',mod_id,'session_id',mod_sid,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase2_room_moderate(rid,guest,'mute',gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Moderator replaced room Owner imposed mute';end if;
 denied:=false;
 begin perform public.phase2_room_moderate(rid,guest,'allow_mic',gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Moderator removed room Owner imposed mute';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',own_sid,'aal','aal1')::text,true);
 perform public.phase2_room_moderate(rid,guest,'allow_mic',gen_random_uuid());
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',mod_id,'session_id',mod_sid,'aal','aal1')::text,true);
 perform public.phase2_room_moderate(rid,guest,'release_seat',gen_random_uuid());
 if exists(select 1 from public.room_members where user_id=guest and seat_no is not null)
 then raise exception 'Released seat still occupied';end if;
 perform public.phase2_room_moderate(rid,guest,'kick',gen_random_uuid());
 if exists(select 1 from public.room_members where user_id=guest)
 then raise exception 'Kick failed to revoke membership';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',guest,'session_id',guest_sid,'aal','aal1')::text,true);
 perform public.phase2_room_join(rid);
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',own_sid,'aal','aal1')::text,true);
 reply:=public.phase2_room_moderate(rid,guest,'ban',key_id,'Repeated abusive behavior');
 if reply->>'success'<>'true' or
    (select count(*) from public.room_bans where user_id=guest)<>1 or
    exists(select 1 from public.room_members where user_id=guest)
 then raise exception 'Owner ban failed to persist and remove membership';end if;
 if public.phase2_room_moderate(rid,guest,'ban',key_id,'Repeated abusive behavior')<>reply
 then raise exception 'Ban idempotency replay was not stable';end if;
 denied:=false;
 begin perform public.phase2_room_moderate(rid,guest,'unban',key_id);
 exception when others then denied:=true;end;
 if not denied then raise exception 'Conflicting action reused ban request ID';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',guest,'session_id',guest_sid,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase2_room_join(rid);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Banned participant rejoined a public room';end if;

 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',outsider,'session_id',outside_sid,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase2_room_moderation_state(rid);
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Outsider read ban/member moderation roster';end if;
 denied:=false;
 begin perform public.phase2_room_moderate(rid,guest,'unban',gen_random_uuid());
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Outsider unbanned a target';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',own_sid,'aal','aal1')::text,true);
 if jsonb_array_length(public.phase2_room_moderation_state(rid)->'bans')<>1
 then raise exception 'Owner ban roster missing entry';end if;
 perform public.phase2_room_moderate(rid,guest,'unban',gen_random_uuid());
 if exists(select 1 from public.room_bans where user_id=guest)
 then raise exception 'Owner unban failed';end if;
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',guest,'session_id',guest_sid,'aal','aal1')::text,true);
 perform public.phase2_room_join(rid);
 -- A second, private room proves the same ban guard protects single-use invites.
 perform public.phase2_room_leave(rid);
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',own_sid,'aal','aal1')::text,true);
 perform public.phase2_room_leave(rid);
 private_id:=public.phase2_room_create('Moderation private',true);
 invite:=public.phase2_room_invite_create(private_id);
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',guest,'session_id',guest_sid,'aal','aal1')::text,true);
 perform public.phase2_room_invite_join(private_id,split_part(invite,':',2));
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',own,'session_id',own_sid,'aal','aal1')::text,true);
 perform public.phase2_room_moderate(private_id,guest,'ban',gen_random_uuid(),'Abuse in private room');
 invite:=public.phase2_room_invite_create(private_id);
 perform set_config('request.jwt.claims',
   jsonb_build_object('sub',guest,'session_id',guest_sid,'aal','aal1')::text,true);
 denied:=false;
 begin perform public.phase2_room_invite_join(private_id,split_part(invite,':',2));
 exception when insufficient_privilege then denied:=true;end;
 if not denied then raise exception 'Banned participant redeemed a private invite';end if;
 if has_table_privilege('authenticated','public.room_bans','INSERT,UPDATE,DELETE')
 or has_table_privilege('authenticated','public.room_moderators','INSERT,UPDATE,DELETE')
 or has_function_privilege('anon','public.phase2_room_moderate(uuid,uuid,text,uuid,text)','EXECUTE')
 then raise exception 'Client bypass privilege on room moderation';end if;
 if (select count(*) from public.security_audit where action like 'room_moderation_%')<5
 then raise exception 'Missing room action audit trail';end if;
end $qa$;
rollback;
select 'PASS: owner-mod actions, denied moderator ban, enforced ban, audit/idempotency without persistent fixtures' as result;
