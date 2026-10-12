-- Staging Only: a single external cash receipt may fund Owner minting once.
-- Immutable JSON payload is indexed without rewriting any issued coins or ledgers.
-- This is enforced transactionally, including concurrent requests and
-- uppercase/lowercase plus surrounding-space variants.
create unique index tc_owner_coin_issue_cash_reference_normalized_unique
on public.financial_operations
 (lower(btrim(payload #>> '{data,cash_reference}')))
where operation='recharge_action'
 and payload->>'action'='issue'
 and payload #>> '{data,cash_reference}' is not null;
