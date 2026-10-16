-- Staging only: one external recharge receipt per agency, even if agent tries
-- upper/lower case or whitespace variations. No balances or rows are rewritten.
-- Existing exact case-sensitive unique (agency_id,cash_reference) stays intact.
create unique index tc_recharge_completed_receipt_normalized_unique
 on public.recharge_requests(agency_id,(lower(btrim(cash_reference))))
 where status='completed' and cash_reference is not null;

alter table public.recharge_requests
 add constraint tc_recharge_completed_receipt_nonblank
 check(status <> 'completed' or
   (cash_reference is not null and char_length(btrim(cash_reference)) between 3 and 120));
