# T06 — Local server-side financial operation limiter verification

- This CI test uses a disposable unlinked Supabase Auth/Postgres stack only.
- Creates a short-lived owner account and JWT session in BEGIN/ROLLBACK.
- Simulates 30 one-coin Owner issuances (all cash references clearly fictional),
  then asserts the 31st unique operation is blocked by the existing per-user
  30/min SQL guard without changing the financial balance.
- Retries the first request with its original request_id to assert idempotency.
- Verifies exactly 30 ledger-backed operations and total 30 coins; rolls all back.
- All committed UI, production wallets, and Supabase production remain unchanged.

## IMPORTANT incomplete security properties

- The existing financial guard counts STORED operations, not invalid/denied calls.
- Authentication spam, unauthenticated traffic, LiveKit Edge token requests,
  and invalid RPC brute-force require independent rate limits at the gateway
  or Edge using a durable counter (e.g. configured Redis).
- Do not alter production SQL or claim complete T06 until these controls are
  configured and tested from independent clients using hosted staging.
- This is not actual cash issuance or a real owner onboarding result.
