-- Staging only: enforce host accrual evidence totals atomically, at COMMIT.
-- Headers are inserted before lines; a deferred constraint avoids partial failures
-- but guarantees no incomplete or mismatched immutable snapshot is persisted.
create function phase3.assert_host_accrual_conservation()
returns trigger language plpgsql security definer set search_path='' as $fn$
declare checked_rows bigint;checked_gifts numeric;checked_diamonds numeric;
begin
 select count(*),coalesce(sum(l.gift_count),0),coalesce(sum(l.earned_diamonds),0)
 into checked_rows,checked_gifts,checked_diamonds
 from phase3.host_month_accrual_lines l
 where l.month_start=new.month_start;
 if checked_rows<>new.entries_count
    or checked_gifts<>new.source_gifts
    or checked_diamonds<>new.total_diamonds then
   raise exception 'Immutable month accrual mismatch; transaction rolled back'
    using errcode='23514';
 end if;
 return new;
end $fn$;
revoke all on function phase3.assert_host_accrual_conservation()
 from public,anon,authenticated;
create constraint trigger tc_host_accrual_commit_conservation
 after insert on phase3.host_month_accrual_headers
 deferrable initially deferred
 for each row execute function phase3.assert_host_accrual_conservation();
