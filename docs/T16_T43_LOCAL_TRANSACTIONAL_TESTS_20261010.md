# T16–T43 — transactional SQL acceptance suite (disposable local Supabase)

CI now runs 13 SQL suites with exact real PostgreSQL stored procedures and
RLS, not browser mocks. Every SQL suite begins with BEGIN and ends with
ROLLBACK, and the database itself is disposable. This does not create real
wallets/users or test transactions in production.

- Identity and room boundaries: T16–T19, T46.
- Owner/catalog/session: T04–T05, T38–T41.
- Wallet, gifting, store, transfer: T24–T29.
- Host agencies, CP and diamond accounting: T30–T35.
- Voice message metadata and reports: T22, T43.
- Financial issuance limits: T06/T29.

The REST/Auth smoke also creates two real ephemeral JWT identities to exercise
private invitation flows and mic seat reservations. It does NOT prove 2 physical
phones, actual microphones, LiveKit streaming, monthly payroll, purchased coins,
or complete UI accessibility. T21/T23/T36/T44/T47–T50 remain release blockers.
All referenced SQL scripts live in supabase/tests/ and include negative scenarios.

DO NOT use this CI as authority to run ANY finance seed or reset in production.
