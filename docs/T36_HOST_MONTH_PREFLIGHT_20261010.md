# T36 — Monthly host accrual preflight (not yet settlement)

This forward-only SQL adds phase5_host_month_preflight(month, offset, limit).
It computes immutable-input sums from diamond_lots joined to the original
gift_events agency association for a CLOSED UTC month. It deliberately
DOES NOT reset operational diamonds, issue salary, write the treasury,
deduct redeemed values, calculate wages, or alter production state.

Authorization is strictly Owner or the one designated main-partner Super Admin
via phase3.admin_session.canManageHostAgencies; additional Super Admin, DB
employee and ordinary accounts cannot execute a successful preflight.

Accounting boundaries: earned = sum(original diamond_lots.amount);
remaining = sum(current lot remaining) which may move after month close,
so this is a **provisional** view and is NOT an immutable month-end snapshot.
Agency mapping uses agency_id fixed on historical gift event.
A user may move agencies and must remain attributed to the gift-time agency.
Month close needs append-only immutable snapshots, exact salaries/host
percentages/agent commissions, reconciliation, month-close idempotency,
Owner approval, verified production restore before any safe zeroing.
These are NOT implemented by this preflight and T36 remains partial.

Local SQL rollback acceptance checks rights and preserves original totals.
No production database or salary is changed.
