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
