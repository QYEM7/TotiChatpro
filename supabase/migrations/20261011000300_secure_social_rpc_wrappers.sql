-- Staging: keep SECURITY DEFINER implementations in private phase3 schema.
-- Exposed public PostgREST RPCs are SECURITY INVOKER only, and require verified active session.
-- Existing RLS, idempotency and data constraints remain intact.
alter function public.phase2_dm_send(uuid,text,uuid) set schema phase3;
alter function public.phase2_dm_thread(uuid,bigint,integer) set schema phase3;
alter function public.phase2_dm_inbox(integer) set schema phase3;
alter function public.phase2_dm_mark_read(uuid,bigint) set schema phase3;
alter function public.phase2_dm_block(uuid,boolean) set schema phase3;
alter function public.phase2_room_customize(uuid,text,text,text) set schema phase3;
alter function public.phase2_voice_token_preflight(uuid) set schema phase3;

revoke all on function phase3.phase2_dm_send(uuid,text,uuid),
 phase3.phase2_dm_thread(uuid,bigint,integer),
 phase3.phase2_dm_inbox(integer),
 phase3.phase2_dm_mark_read(uuid,bigint),
 phase3.phase2_dm_block(uuid,boolean),
 phase3.phase2_room_customize(uuid,text,text,text),
 phase3.phase2_voice_token_preflight(uuid)
 from public,anon;
grant execute on function phase3.phase2_dm_send(uuid,text,uuid),
 phase3.phase2_dm_thread(uuid,bigint,integer),
 phase3.phase2_dm_inbox(integer),
 phase3.phase2_dm_mark_read(uuid,bigint),
 phase3.phase2_dm_block(uuid,boolean),
 phase3.phase2_room_customize(uuid,text,text,text),
 phase3.phase2_voice_token_preflight(uuid)
 to authenticated;

create function public.phase2_dm_send(p_recipient_id uuid,p_body text,p_request_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
begin
 perform phase3.actor();
 return phase3.phase2_dm_send(p_recipient_id,p_body,p_request_id);
end $$;
create function public.phase2_dm_thread(p_other_user uuid,p_before_id bigint default null,p_limit integer default 50)
returns table(id bigint,sender_id uuid,recipient_id uuid,body text,created_at timestamptz,read_at timestamptz)
language plpgsql security invoker set search_path='' as $$
begin
 perform phase3.actor();
 return query select * from phase3.phase2_dm_thread(p_other_user,p_before_id,p_limit);
end $$;
create function public.phase2_dm_inbox(p_limit integer default 30)
returns table(other_user_id uuid,other_display_name text,last_id bigint,last_body text,
 last_at timestamptz,unread_count bigint)
language plpgsql security invoker set search_path='' as $$
begin
 perform phase3.actor();
 return query select * from phase3.phase2_dm_inbox(p_limit);
end $$;
create function public.phase2_dm_mark_read(p_other_user uuid,p_through_id bigint default null)
returns integer language plpgsql security invoker set search_path='' as $$
begin
 perform phase3.actor();
 return phase3.phase2_dm_mark_read(p_other_user,p_through_id);
end $$;
create function public.phase2_dm_block(p_other_user uuid,p_block boolean)
returns boolean language plpgsql security invoker set search_path='' as $$
begin
 perform phase3.actor();
 return phase3.phase2_dm_block(p_other_user,p_block);
end $$;
create function public.phase2_room_customize(p_room_id uuid,p_welcome_message text default null,
 p_cover_path text default null,p_background_path text default null)
returns boolean language plpgsql security invoker set search_path='' as $$
begin
 perform phase3.actor();
 return phase3.phase2_room_customize(p_room_id,p_welcome_message,p_cover_path,p_background_path);
end $$;
create function public.phase2_voice_token_preflight(p_room_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
begin
 perform phase3.actor();
 return phase3.phase2_voice_token_preflight(p_room_id);
end $$;

revoke all on function public.phase2_dm_send(uuid,text,uuid),
 public.phase2_dm_thread(uuid,bigint,integer),
 public.phase2_dm_inbox(integer),
 public.phase2_dm_mark_read(uuid,bigint),
 public.phase2_dm_block(uuid,boolean),
 public.phase2_room_customize(uuid,text,text,text),
 public.phase2_voice_token_preflight(uuid)
 from public,anon;
grant execute on function public.phase2_dm_send(uuid,text,uuid),
 public.phase2_dm_thread(uuid,bigint,integer),
 public.phase2_dm_inbox(integer),
 public.phase2_dm_mark_read(uuid,bigint),
 public.phase2_dm_block(uuid,boolean),
 public.phase2_room_customize(uuid,text,text,text),
 public.phase2_voice_token_preflight(uuid)
 to authenticated;
