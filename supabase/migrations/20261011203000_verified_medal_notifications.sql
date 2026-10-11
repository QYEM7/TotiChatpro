-- TotiChat actual medal awards -> private, proof-backed in-app notifications.
-- Extend preexisting verified audit trigger; no replay or fake backfill.
alter table public.user_notifications
 drop constraint if exists user_notifications_event_type_check;
alter table public.user_notifications
 add constraint user_notifications_event_type_check check(event_type in(
 'vip_granted','vip_revoked','room_moderator_granted','room_moderator_revoked',
 'room_kicked','room_banned','room_unbanned','room_muted','room_mic_allowed',
 'room_seat_released','support_staff_replied','medal_granted','medal_revoked'));

create or replace function phase3.notification_on_audit()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare kind text;target uuid;target_text text;roomid text;medal text;
begin
 kind:=case new.action
 when 'vip_grant' then 'vip_granted'
 when 'vip_revoke' then 'vip_revoked'
 when 'room_moderation_grant_moderator' then 'room_moderator_granted'
 when 'room_moderation_revoke_moderator' then 'room_moderator_revoked'
 when 'room_moderation_kick' then 'room_kicked'
 when 'room_moderation_ban' then 'room_banned'
 when 'room_moderation_unban' then 'room_unbanned'
 when 'room_moderation_mute' then 'room_muted'
 when 'room_moderation_allow_mic' then 'room_mic_allowed'
 when 'room_moderation_release_seat' then 'room_seat_released'
 when 'medal_grant' then 'medal_granted'
 when 'medal_revoke' then 'medal_revoked'
 else null end;
 if kind is null then return new;end if;
 -- Only normalized target IDs from committed audited server actions.
 target_text:=new.details->>'targetId';
 if target_text is null or target_text !~
  '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
 then return new;end if;
 target:=target_text::uuid;
 if target=new.actor_id then return new;end if;
 roomid:=new.details->>'roomId';
 medal:=new.details->>'medalKey';
 insert into public.user_notifications(recipient_id,event_type,source_type,source_id,context)
 values(target,kind,'security_audit',new.id,
 case when kind like 'vip_%' then
   jsonb_build_object('tier',new.details->'tier','expiresAt',new.details->'expiresAt')
 when kind like 'medal_%' then
   jsonb_build_object('medalKey',medal)
 else jsonb_build_object('roomId',roomid) end)
 on conflict(recipient_id,source_type,source_id) do nothing;
 return new;
end $fn$;
revoke all on function phase3.notification_on_audit() from public,anon,authenticated;
comment on function phase3.notification_on_audit() is
 'Verified security_audit-triggered VIP, room moderation and medal award inbox events. Never transmit private support text or wallet information.';
