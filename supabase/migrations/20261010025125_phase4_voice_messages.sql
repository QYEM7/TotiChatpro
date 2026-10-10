insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('voice-messages','voice-messages',false,10485760,array['audio/webm','audio/ogg','audio/mp4']) on conflict(id) do nothing;
create table public.voice_messages (
 id uuid primary key,room_id uuid not null references public.rooms(id),sender_id uuid not null references auth.users(id),
 object_path text not null unique,mime_type text not null check(mime_type in('audio/webm','audio/ogg','audio/mp4')),
 size_bytes integer not null check(size_bytes between 1 and 10485760),duration_ms integer not null check(duration_ms between 1 and 120000),
 created_at timestamptz not null default now(),deleted_at timestamptz
);
create index voice_messages_room_created_idx on public.voice_messages(room_id,created_at desc);
create index voice_messages_sender_idx on public.voice_messages(sender_id);
alter table public.voice_messages enable row level security;
revoke all on public.voice_messages from public,anon,authenticated;
create function phase3.voice_object_access(p_name text,p_mode text) returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();parts text[];r uuid;
begin
 parts:=string_to_array(p_name,'/');
 if array_length(parts,1)<>3 or parts[1]!~'^[0-9a-f-]{36}$' or parts[2]!~'^[0-9a-f-]{36}$' or parts[3]!~'^[0-9a-f-]{36}\.(webm|ogg|mp4)$' then return false;end if;
 begin r:=parts[2]::uuid;exception when invalid_text_representation then return false;end;
 if p_mode='delete' then return parts[1]=u::text;end if;
 if p_mode='write' then return parts[1]=u::text and exists(select 1 from public.room_members where room_id=r and user_id=u);end if;
 if p_mode='read' then return parts[1]=u::text or (exists(select 1 from public.room_members where room_id=r and user_id=u) and exists(select 1 from public.voice_messages where object_path=p_name and deleted_at is null));end if;
 return false;
end $$;
revoke all on function phase3.voice_object_access(text,text) from public,anon,authenticated;
grant execute on function phase3.voice_object_access(text,text) to authenticated;
create policy phase4_voice_object_insert on storage.objects for insert to authenticated with check(bucket_id='voice-messages' and phase3.voice_object_access(name,'write'));
create policy phase4_voice_object_read on storage.objects for select to authenticated using(bucket_id='voice-messages' and phase3.voice_object_access(name,'read'));
create policy phase4_voice_object_delete on storage.objects for delete to authenticated using(bucket_id='voice-messages' and phase3.voice_object_access(name,'delete'));
create function phase3.voice_message(p_action text,p_id uuid,p_room_id uuid default null,p_path text default null,p_mime text default null,p_size integer default null,p_duration integer default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();m public.voice_messages%rowtype;answer jsonb;meta jsonb;
begin
 if p_action is null or p_action not in('create','delete') or p_id is null then raise exception 'Invalid voice operation';end if;
 select * into m from public.voice_messages where id=p_id for update;
 if p_action='delete' then
  if not found or m.sender_id<>u then raise exception 'Voice message owner required' using errcode='42501';end if;
  if m.deleted_at is not null then return to_jsonb(m);end if;
  update public.voice_messages set deleted_at=now() where id=m.id returning * into m;
 else
  if found then
   if m.sender_id<>u or m.room_id is distinct from p_room_id or m.object_path is distinct from p_path or m.mime_type is distinct from p_mime or m.size_bytes is distinct from p_size or m.duration_ms is distinct from p_duration then raise exception 'Voice idempotency conflict';end if;
   return to_jsonb(m);
  end if;
  if p_room_id is null or p_path is null or p_mime is null or p_size is null or p_duration is null or p_duration not between 1 and 120000 or p_size not between 1 and 10485760 or p_mime not in('audio/webm','audio/ogg','audio/mp4') then raise exception 'Invalid audio metadata';end if;
  if not phase3.voice_object_access(p_path,'write') or split_part(p_path,'/',2)<>p_room_id::text or split_part(split_part(p_path,'/',3),'.',1)<>p_id::text then raise exception 'Invalid voice upload path' using errcode='42501';end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=u) then raise exception 'Room membership required' using errcode='42501';end if;
  if (select count(*) from public.voice_messages where sender_id=u and created_at>now()-interval '1 minute')>=10 then raise exception 'Voice message rate limit';end if;
  select metadata into meta from storage.objects where bucket_id='voice-messages' and name=p_path for share;
  if not found or (meta->>'size')::bigint is distinct from p_size::bigint or split_part(meta->>'mimetype',';',1) is distinct from p_mime then raise exception 'Uploaded audio metadata mismatch';end if;
  insert into public.voice_messages(id,room_id,sender_id,object_path,mime_type,size_bytes,duration_ms) values(p_id,p_room_id,u,p_path,p_mime,p_size,p_duration) returning * into m;
 end if;
 answer:=to_jsonb(m);insert into public.security_audit(actor_id,action,details) values(u,'voice_message_'||p_action,jsonb_build_object('id',m.id,'room_id',m.room_id));return answer;
end $$;
create function phase3.voice_messages(p_room_id uuid,p_before timestamptz default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();rows jsonb;
begin
 if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=u) then raise exception 'Room membership required' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(r)),'[]') into rows from (select m.*,p.display_name from public.voice_messages m join public.profiles p on p.id=m.sender_id where m.room_id=p_room_id and m.deleted_at is null and (p_before is null or m.created_at<p_before) order by m.created_at desc,m.id limit 50) r;return rows;
end $$;
create function public.phase4_voice_message(p_action text,p_id uuid,p_room_id uuid default null,p_path text default null,p_mime text default null,p_size integer default null,p_duration integer default null) returns jsonb language sql security invoker set search_path='' as $$select phase3.voice_message(p_action,p_id,p_room_id,p_path,p_mime,p_size,p_duration)$$;
create function public.phase4_voice_messages(p_room_id uuid,p_before timestamptz default null) returns jsonb language sql security invoker set search_path='' as $$select phase3.voice_messages(p_room_id,p_before)$$;
revoke all on function phase3.voice_message(text,uuid,uuid,text,text,integer,integer),phase3.voice_messages(uuid,timestamptz),public.phase4_voice_message(text,uuid,uuid,text,text,integer,integer),public.phase4_voice_messages(uuid,timestamptz) from public,anon,authenticated;
grant execute on function phase3.voice_message(text,uuid,uuid,text,text,integer,integer),phase3.voice_messages(uuid,timestamptz),public.phase4_voice_message(text,uuid,uuid,text,text,integer,integer),public.phase4_voice_messages(uuid,timestamptz) to authenticated;
