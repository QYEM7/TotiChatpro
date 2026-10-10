# T42 — real customer support tickets (development verified, production pending)

Date: 2026-10-10. Repository: QYEM7/TotiChatpro / develop/phase-2.

## Implemented
- Private Postgres tables in phase3: support_staff, support_tickets, support_messages, support_requests. All have RLS enabled; no direct anon or authenticated table grants.
- Authenticated public RPCs: phase5_support_list, phase5_support_thread and phase5_support_action (each SECURITY DEFINER with an explicit verified session and server-side authorization).
- Customer: create scoped categorized tickets, see only their own tickets, read historical replies, reply to open/resolved tickets; real DB errors are surfaced, never replaced with fictional responses.
- Owner: can grant and revoke separate support-staff permissions (only Owner, not another Super Admin or the designated partner).
- Designated main partner and enabled support agents: read ticket queue, reply, resolve/close; cannot use this authority to open host/recharge agencies or issue coins.
- Every mutation requires a UUID idempotency key; retries return the same result and conflicting payloads fail. Per-actor throttling 20 operations/min and maximum five open tickets per creator.
- Sensitive ticket messages remain inside private tables and are not copied into shared security_audit details. Request ledger and all state changes are server-controlled.
- Account settings includes support/tickets entry and loads the independent UI module. Original app/index.html and original accepted room decoration remain unchanged.

## Evidence (verified)
- [Foundation CI at 29af866](https://github.com/QYEM7/TotiChatpro/actions/runs/38058853187): successful after fixing a test assertion that incorrectly assumed begin was the first line of commented SQL fixture.
- [Disposable full-stack CI](https://github.com/QYEM7/TotiChatpro/actions/runs/38058790264): successful; includes t42_support_tickets.sql inside transaction rollback on unlinked Docker Supabase, exercising authenticated five-user authorization, staff delegation/revocation, replay, list privacy, reply and status handling. This is a LOCAL service test, not a hosted production two-phone acceptance.
- Node syntax, static T42 security contracts and baseline UI integrity passed in foundation.
- Production migration list was separately read: 32 applied vs 37 committed after T42. Production contains zero accounts/rooms, and T42 is not deployed.

## Deferred / still incomplete
- Hosted staging with verified backup and controlled migration publication (five pending files, including T42).
- Device acceptance with genuine staff/customer accounts and accessibility/keyboard tests.
- SLA timer, escalations, abuse reports, push/email notifications, message pagination beyond first 500, staff-management UI and customer service operating procedures.
- Host-agency opening and exceptional host transfer remain independently reviewed agency workflows. Filing a ticket only requests investigation, never auto-approves agency or transfer.
- Production use is blocked until rollout validation, recoverability and permissions review.

No production tables, wallets, rooms, diamonds or historical records were changed by T42.

## Follow-up: Owner staff management and real browser behavior verified
- Added a real Owner-only support-staff assignment form in the support sheet. The Owner can grant or revoke support permission by the verified account UUID. No financial/agency authorization is assigned in this workflow.
- The Owner capability is fetched from `phase3_admin_session` and checked on the server again by `phase5_support_action`; an old async capability response is ignored after a user/account/dialog change.
- A dedicated quick Chromium workflow was added for customer ticket creation and response, Owner staff grant, non-owner restriction, all-inbox visibility, logout removal, and mobile viewport width using isolated API fixtures. No fake records are inserted into production.
- Chrome acceptance exposed an input typo: UUID was validated as 8-4-4-4-4-12 rather than 8-4-4-4-12. Corrected in commit `a756e3289b06`.
- Latest [isolated Chromium T42 QA](https://github.com/QYEM7/TotiChatpro/actions/runs/38059820436): **PASS**.
- Latest [foundation CI](https://github.com/QYEM7/TotiChatpro/actions/runs/38059820406): **PASS**.
- Local disposable five-actor PostgreSQL transaction replay remains previously [PASS](https://github.com/QYEM7/TotiChatpro/actions/runs/38058790264); it is unchanged by this UI-only follow-up.
- Full Royal browser suite and APK rebuild are checked separately; passing unit/sandbox tests does not prove live device acceptance.

Remaining: Support staff inventory, SLA, escalation, message paging, hosted staging and two physical Android accounts; T42 stays **partial**.
