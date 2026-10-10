-- T06/T42 concurrency hardening, forward-only, development only.
-- Existing 32 production migrations remain unchanged; do not deploy without backup/restore.
-- SHA-256 retry fingerprint is not a message and prevents duplicate private plaintext storage.
create or replace function public.phase5_support_action(p_action text,p_data jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare u uuid:=phase3.actor();is_owner boolean:=phase3.is_owner();
 staff boolean; old phase3.support_requests%rowtype;
 payload jsonb;fingerprint jsonb;t phase3.support_tickets%rowtype;outcome jsonb;
 subject_text text; message_text text; note_status text; category_text text; target uuid;
begin
 if p_action is null or p_action not in('create','reply','status','staff_grant','staff_revoke')
    or p_data is null or jsonb_typeof(p_data)<>'object' or
    octet_length(p_data::text)>6500 or p_request_id is null then
   raise exception 'Invalid support action';
 end if;
 staff:=is_owner or exists(select 1 from phase3.system_authority a where a.singleton and a.main_partner_id=u)
   or exists(select 1 from phase3.support_staff s where s.user_id=u and s.enabled);
 payload:=jsonb_build_object('action',p_action,'data',p_data);
 -- A transaction-scoped per-actor lock closes concurrent count/IDEMPOTENCY races.
 -- Locks never refer to another account's UUID: u comes from verified phase3.actor().
 perform pg_advisory_xact_lock(hashtextextended('totichat-support:'||u::text,0));
 -- Keep only a canonical SHA-256 fingerprint of user content in the private retry ledger.
 -- The actual message remains solely in phase3.support_messages with strict RLS.
 fingerprint:=jsonb_build_object('sha256',encode(sha256(convert_to(payload::text,'UTF8')),'hex'));
 select * into old from phase3.support_requests r
 where r.actor_id=u and r.request_id=p_request_id;
 if found then
   if old.payload<>fingerprint and old.payload<>payload then raise exception 'Idempotency key conflict';end if;
   return old.result;
 end if;
 if (select count(*) from phase3.support_requests r where r.actor_id=u
    and r.created_at>now()-interval '1 minute')>=20 then
   raise exception 'Support rate limit exceeded';
 end if;
 if p_action='create' then
   category_text:=p_data->>'category';subject_text:=btrim(p_data->>'subject');
   message_text:=btrim(p_data->>'message');
   if category_text is null or category_text not in ('general','technical','account','recharge','host_agency','host_transfer')
      or subject_text is null or char_length(subject_text) not between 5 and 120
      or message_text is null or char_length(message_text) not between 2 and 2500 then
     raise exception 'A category, subject and message are required';
   end if;
   if (select count(*) from phase3.support_tickets x where x.creator_id=u
       and x.status in('open','in_progress','waiting_user'))>=5 then
     raise exception 'Please resolve an open ticket before creating another';
   end if;
   insert into phase3.support_tickets(creator_id,category,subject)
   values(u,category_text,subject_text) returning * into t;
   insert into phase3.support_messages(ticket_id,author_id,body)
   values(t.id,u,message_text);
   outcome:=jsonb_build_object('id',t.id,'status',t.status);
 elsif p_action in('staff_grant','staff_revoke') then
   if not is_owner then raise exception 'Owner alone grants support access' using errcode='42501';end if;
   target:=(p_data->>'user_id')::uuid;
   if target is null or target=u or not exists(
     select 1 from auth.users au where au.id=target and au.email_confirmed_at is not null
     and au.deleted_at is null and (au.banned_until is null or au.banned_until<now())
   ) then raise exception 'Verified distinct staff user required';end if;
   insert into phase3.support_staff(user_id,enabled,granted_by)
   values(target,p_action='staff_grant',u)
   on conflict(user_id) do update set enabled=excluded.enabled,
     granted_by=excluded.granted_by,updated_at=now();
   outcome:=jsonb_build_object('id',target,'enabled',p_action='staff_grant');
 else
   if p_data->>'ticket_id' is null then raise exception 'Ticket ID required';end if;
   select * into t from phase3.support_tickets where id=(p_data->>'ticket_id')::uuid for update;
   if not found or (t.creator_id<>u and not staff) then
     raise exception 'Ticket not found' using errcode='42501';
   end if;
   if p_action='reply' then
     if t.status='closed' then raise exception 'Closed ticket cannot receive replies';end if;
     message_text:=btrim(p_data->>'message');
     if message_text is null or char_length(message_text) not between 2 and 2500 then
       raise exception 'Message must be 2 to 2500 characters';
     end if;
     insert into phase3.support_messages(ticket_id,author_id,body) values(t.id,u,message_text);
     update phase3.support_tickets
       set status=case when staff and u<>creator_id then 'waiting_user' else 'open' end,
           first_staff_reply_at=case when staff and u<>creator_id then coalesce(first_staff_reply_at,now()) else first_staff_reply_at end,
           assigned_to=case when staff and u<>creator_id then u else assigned_to end,
           updated_at=now()
       where id=t.id returning * into t;
   else
     if not staff then raise exception 'Support staff required' using errcode='42501';end if;
     note_status:=p_data->>'status';
     if note_status is null or note_status not in ('open','in_progress','resolved','closed') then
       raise exception 'Invalid ticket status';
     end if;
     update phase3.support_tickets
       set status=note_status,closed_at=case when note_status='closed' then now() else null end,
           updated_at=now()
       where id=t.id returning * into t;
   end if;
   outcome:=jsonb_build_object('id',t.id,'status',t.status);
 end if;
 insert into phase3.support_requests(actor_id,request_id,payload,result)
 values(u,p_request_id,fingerprint,outcome);
 insert into public.security_audit(actor_id,action,details)
 values(u,'support_'||p_action,jsonb_build_object('id',outcome->>'id','request_id',p_request_id));
 return outcome;
end $fn$;

comment on function public.phase5_support_action(text,jsonb,uuid) is
 'T06/T42: verified session, serial per-user support limits, SHA-256 retry digest; no agency/wallet grants.';
