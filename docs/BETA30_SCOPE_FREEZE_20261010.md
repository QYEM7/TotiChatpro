# TotiChat — 30-day lean beta: OWNER-APPROVED SCOPE FREEZE
**Approved:** 2026-10-10 | **Project:** TotiChatpro (user app name TotiChat) | **Budget:** $0 | **Branch:** `develop/phase-2`

## Non-negotiable Owner decision
Stop expanding ANY nonessential feature for the 30-day beta. **This is a work-priority freeze, NOT deletion, shutdown, hiding or redesign of already approved features.** Keep the exact 15 seat room design, VIP frames, visual effects, gifts, navigation and other approved UI elements. Existing optional code stays in source control. No production changes, no new paid services, and no APK build are authorized by this decision.

**Small scope, production-quality operations.** Use human-reviewed operations inside a real audited TotiChat admin dashboard. Never substitute manual edits in Supabase SQL as the primary business workflow. Human decision, protected atomic server transaction, stored evidence, unique reference, audit, no repeated execution.

## Required beta user experience
1. **Google OAuth ONLY** via Supabase Auth PKCE, real Android/web callbacks, protected Owner/partner identities; real profile. No email/password or Apple/Facebook in beta. Admin-granted **unique special public ID** only; immutable internal Auth UUID stays system-managed.
2. Public/private rooms, Realtime list and chat, **all 15 mic seats** with actual two-phone voice, mute/unmute, moderation, reconnect. Room layout and effects preserved unchanged.
3. Real wallet/ledger, recipient-then-gift-then-confirm send flow, ordinary **and luck gifts** with owner-approved published odds, cryptographically secure server-side draws, audited and idempotent payouts; no fake balances/wins. Existing **VIP1–VIP10 must be purchasable and activated on profile**, without creating new VIP tiers/features.
4. Human-managed external cash recharge: Owner treasury issue/allocation to approved recharge agent; agent manually verifies cash and approves customer request; customer wallet credited exactly once with linked cash reference. No IAP.
5. Human-operated host agency requests via customer support, restricted Owner/designated main-partner administration, limited DB-host-opening delegation but **never** recharge-agency opening, old-agent consent / investigated exception workflow.
6. Human-operated monthly payroll: staff set/verify monthly host diamonds, targets, salary, agent commissions and liabilities; authorized final approval creates immutable settlement entitlements and audit **BEFORE** any permitted month-end diamond clearing. Unpaid earnings remain payable and untouched by display reset. Do not execute a simple SQL `UPDATE wallets SET diamonds=0`.
7. Basic Owner/staff dashboard for real user, room, recharge, host agency, decisions and reports; scoped support tickets and staff oversight.
8. Working beta-visible controls, preserved visual identity, Google OAuth Android callback verified; SMTP only for necessary non-login notifications, monitoring, security checks and independent backup/restore evidence, real two-phone QA.

## Feature expansion paused for this beta (do NOT delete approved code or silently hide UI)
| Task | Deferred expansion | Rule |
|---|---|---|
| T22 | Voice messages stored securely | الرسائل الصوتية المسجلة إضافة غير لازمة للمكالمات المباشرة؛ لا تُحذف ملفاتها أو واجهتها. |
| T28 | P2P coins | تحويل العملات بين المستخدمين P2P غير لازم للشحن اليدوي عبر وكيل؛ يبقى الكود دون توسيع. |
| T32 | CP relationships levels | الخصائص المتقدمة لعلاقات CP تُجمّد؛ الحفاظ على الرسوم والواجهة وعدم إعلان ميزة غير فعّالة. |
| T44 | Solo and multiplayer in-room games | الألعاب الفردية والجماعية تؤجل هذه الجولة؛ لا حذف أو إخفاء صامت للزر والتصميم، ولا واجهة تدّعي التشغيل. |

**Other enhancements limited to smallest safe version:** T06 advanced fraud analytics, T23 licensed synchronized music, T27 extended catalog, T31 advanced bonus rules, T36 fully automated wages, T40 whole enterprise admin breadth, T42 complex SLAs, T43 advanced analytics etc. Features advertised in the first beta MUST work. Where an existing visible control belongs to a deferred feature, **do not delete/hide/redesign silently and do not pretend functionality**; resolve the release UI honestly with Owner approval before beta users join.

## Owner clarification: required login, special ID, luck gifts and existing VIP
- **Google-only:** native/web PKCE must be tested before removing working production login. Do not lock existing active admin accounts without verified mapped Google identities. Disable email/password and other providers in the final beta configuration, not merely by hiding UI buttons. Google account recovery is via Google.
- **Special ID:** manual assignment by authorized admin from a protected dashboard; optional premium public identifier with unique constraint, anti-impersonation and immutable audit. Internal Supabase UUID is still system-generated and MUST NOT be made editable.
- **Luck gifts:** mandatory in beta; rates/prizes approved by Owner, published before purchase, truly random server-side with wallet-transaction idempotency, fraud controls, audit and legal review if redeemable coins/diamonds are involved. No invented odds.
- **VIP:** currently approved VIP1 to VIP10 must be buyable and activated with saved purchase, expiry, frames and benefits; **pause only NEW VIP tiers/benefits**.

## Manual financial operations — acceptance tests
| Workflow | Human actions inside TotiChat admin | Software MUST guarantee |
|---|---|---|
| Owner issue coins | Enter independent cash/receipt proof, review and approve | Owner-only, single issuance per receipt and idempotency key, issuance/treasury ledger balanced |
| Allocate to reseller | Owner selects verified agent and quantity | Debits Owner treasury and credits agent exactly once, no negative balances |
| Agent credits customer | Receive cash outside app, agent approves correct user's request with receipt note | Single atomic credit; replay blocked, immutable request/ledger/audit, separate host/recharge permissions |
| Host agency opening | Support intake; Owner or designated partner approves; limited DB workflow only when approved | No unrelated Super Admin full access; DB cannot open recharge agency |
| Move host to new agency | Old agent approval then new agent acceptance; exceptional conflict investigated by Owner/partner | Evidence, request states, no double membership, historic host/gift snapshots preserved |
| Month-end diamond close | Staff inputs rates, totals, commissions and external payout evidence; authorized approval | Immutable accrued due + unpaid rights recorded BEFORE clearing; two-step authorization, duplicate-month close denied, reversible corrections only through new audit entries |

## Stable priorities from the 50 task ledger
- `required_for_beta`: 28
- `minimum_for_beta`: 18 — only the smallest safe supported feature, NO extras
- `paused_after_beta`: 4 — park all expansion now
- **Completion statuses remain unchanged:** 3 `tested_local`, 36 `partial`, 11 `blocked`. No task is promoted to `verified_live` without real evidence.

Run tasks in dependency order: **T49/T03/T07** recovery/staging/branch protection → **T05/T13/T14/T15** Google real identity and special ID → **T16–T21/T09–T11** voice + room + visual interaction on two devices → **T24/T25/T26/T27/T29/T30/T33/T34/T35/T36/T37/T38/T39/T40/T41/T42/T43** audited minimal manual administration → **T45/T46/T47** hardware and security verification → **T48/T50** authorized build and 30-day beta.

Keep Firebase additions lean: Crashlytics for crashes, FCM only where real notification need and verified free plan; no new Firebase money database. Cloudflare for static site (GitHub Releases holds APK only after gate); postpone D1, Turso, Neon, Redis, R2, complex Workers, CP/game/bonus growth until justified by measured use and affordable maintenance.

## T48 build/release gate remains unchanged
**Engineering >=80% AND real Beta readiness >=80%, PLUS >=40/50 tasks with actual live evidence, AND all 9 recovery/staging/two-phone/audio/finance/security/mobile proof flags verified, explicit Owner approval, reviewer and date.** Existing gate is still DENY; currently 63% engineering and 15% beta. No APK/AAB builds, no weakening the gate to meet an arbitrary date. The 4 paused tasks leave at most 46 live-verifiable tasks; plan accordingly and do not count deferred tasks as verified.

## Practical next work, now
**ONLY work on the smallest Owner/Admin manual operations and on technical launch blockers.** First inspect existing Owner recharge RPC, host agency RPC and T36 read-only monthly preflight before writing anything new. Implement protected receipt/audit/manual settlement and Staging tests first. Do not invent payroll rates or payment evidence.

This document overrides older *priority or expansion* roadmaps **only for the first 30-day beta**; it does NOT retroactively delete historical tasks or Owner-approved aesthetics/business rules.
