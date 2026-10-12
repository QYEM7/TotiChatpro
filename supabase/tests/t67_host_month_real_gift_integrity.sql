-- T67: Genuine SQL transaction + auth actor tests on a disposable local Supabase DB.
-- All users, agencies, gifts, and tampering fixtures ROLLBACK. NEVER execute on hosted Staging.
begin;
do $t67$
declare
 qa_owner uuid:=gen_random_uuid(); qa_host uuid:=gen_random_uuid();
 session_id uuid:=gen_random_uuid(); room_id uuid:=gen_random_uuid();
 qa_agency uuid:=gen_random_uuid(); closed_month date:=(date_trunc('month',now() at time zone 'UTC')::date-interval '1 month')::date;
 bad_month date:=(date_trunc('month',now() at time zone 'UTC')::date-interval '2 months')::date;
 gift1 jsonb; gift2 jsonb; gift3 jsonb;
 preview jsonb; captured jsonb; after_capture jsonb;
 failed boolean;
begin
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values (qa_owner,qa_owner::text||'@test.invalid',now(),false),
        (qa_host,qa_host::text||'@test.invalid',now(),false);
 insert into auth.sessions(id,user_id) values(session_id,qa_owner);
 update phase3.system_authority set owner_id=qa_owner,main_partner_id=null where singleton;
 insert into public.rooms(id,owner_id,title,is_private)
 values(room_id,qa_owner,'T67 disposable host evidence',false);
 insert into public.room_members(room_id,user_id)
 values(room_id,qa_owner),(room_id,qa_host);
 insert into public.agencies(id,owner_id,kind,name,commission_percent,created_by)
 values(qa_agency,qa_owner,'host','T67 disposable host agency',0,qa_owner);
 insert into public.agency_members(user_id,agency_id)
 values(qa_host,qa_agency);
 update public.wallets set coins=100 where user_id=qa_owner;
 perform set_config('request.jwt.claims',jsonb_build_object(
   'sub',qa_owner,'session_id',session_id,'aal','aal1','role','authenticated')::text,true);
 -- Real gift API call causes payment, the immutable gift event and issued diamond lot.
 gift1:=public.phase3_send_gift(room_id,qa_host,'g1',1,gen_random_uuid(),10);
 if (gift1->>'id') is null then raise exception 'T67 no original gift event';end if;
 if not exists(select 1 from public.gift_events g where g.id=(gift1->>'id')::uuid
   and g.agency_id=qa_agency and g.recipient_id=qa_host) then
  raise exception 'T67 gift did not preserve historical host agency identity';
 end if;
 -- Backdating happens in the disposable test only; data is never committed.
 update public.gift_events set created_at=closed_month::timestamp at time zone 'UTC' +interval '14 days'
 where id=(gift1->>'id')::uuid;
 preview:=public.phase6_host_month_evidence_integrity(closed_month);
 if preview->>'hostGiftEvents'<>'1' or preview->>'verifiedHostGiftEvents'<>'1'
    or preview->>'hostGiftDiamonds'<>'10' or preview->>'snapshotCaptured'<>'false'
    or preview->>'canPaySalaries'<>'false' or preview->>'canZeroDiamonds'<>'false' then
  raise exception 'T67 genuine gift preview unexpected: %',preview;
 end if;
 captured:=public.phase5_host_month_snapshot_capture(closed_month,gen_random_uuid());
 if captured->>'captured'<>'true' or captured->>'alreadyCaptured'<>'false'
    or captured->>'isAccrualEvidenceOnly'<>'true' then
  raise exception 'T67 verified accrual capture failed: %',captured;
 end if;
 after_capture:=public.phase6_host_month_evidence_integrity(closed_month);
 if after_capture->>'snapshotCaptured'<>'true'
   or after_capture->>'snapshotConsistent'<>'true'
   or after_capture->>'snapshotGroupMismatches'<>'0' then
  raise exception 'T67 valid snapshot did not conserve diamonds: %',after_capture;
 end if;
 -- Tamper an old historical gift ONLY inside rolled-back local SQL to verify
 -- the read-only report discovers it. Never modify a live payment ledger.
 update public.gift_events set amount=11 where id=(gift1->>'id')::uuid;
 preview:=public.phase6_host_month_evidence_integrity(closed_month);
 if preview->>'hasEvidenceProblems'<>'true'
   or preview->>'hostGiftsMissingOrMismatchedLots'<>'1'
   or preview->>'snapshotConsistent'<>'false' then
   raise exception 'T67 tampered gift evidence was silently accepted: %',preview;
 end if;
 update public.gift_events set amount=10 where id=(gift1->>'id')::uuid;
 -- A different closed month has TWO gifts: one valid and one with its lot
 -- deliberately deleted (disposable PostgreSQL only). Header insert must fail.
 gift2:=public.phase3_send_gift(room_id,qa_host,'g1',1,gen_random_uuid(),10);
 gift3:=public.phase3_send_gift(room_id,qa_host,'g1',1,gen_random_uuid(),10);
 update public.gift_events set created_at=bad_month::timestamp at time zone 'UTC'+interval '11 days'
 where id in ((gift2->>'id')::uuid,(gift3->>'id')::uuid);
 delete from public.diamond_lots where gift_event_id=(gift3->>'id')::uuid;
 failed:=false;
 begin
  perform public.phase5_host_month_snapshot_capture(bad_month,gen_random_uuid());
 exception when check_violation then failed:=true;
 end;
 if not failed then raise exception 'T67 incomplete monthly snapshot was accepted';end if;
 if exists(select 1 from phase3.host_month_accrual_headers where month_start=bad_month) then
  raise exception 'T67 failed capture left behind a partially committed header';
 end if;
 preview:=public.phase6_host_month_evidence_integrity(bad_month);
 if preview->>'hasEvidenceProblems'<>'true' or
    preview->>'hostGiftsMissingOrMismatchedLots'<>'1' then
  raise exception 'T67 missing diamond lot was not detected';
 end if;
 if (select count(*) from phase3.host_month_accrual_lines where month_start=closed_month)<>1 then
  raise exception 'T67 correct month accrual changed due to unrelated second month';
 end if;
end $t67$;
rollback;
select 'PASS T67: real disposable gift, genuine month snapshot, tampering detected, incomplete second month blocked, 100% rollback, no payout/diamond reset' as result;
