# TotiChat — Frontend acceptance and backend handoff

> Status: **Frontend preview and interactive prototypes; NOT a production-ready mobile or backend release.**  
> Approved visual system: **Bloom Signature** (do not recolor, remove decorations, hide seats, or change screen navigation without explicit owner approval).  
> Entry point: `/app/` · Repository: `QYEM7/TotiChatpro`.

## Frontend structure and boundaries

| Area | Present UI | Data provenance and backend blocker |
| --- | --- | --- |
| Home, room discovery and navigation | Home tabs, visually detailed cards, event banners, navigable rooms | Dynamic catalog and realtime online presence pending |
| Voice room | 15 original seats, moderation and room controls, gifts, chat, visual effects | Authoritative realtime audio, permissions, presence and event sync pending |
| Music | File playlist prototype with local IndexedDB and playback control | Server-hosted synchronized room playback, moderation and licensed media pending |
| VIP, achievements, CP, profile | Complete visual flows and available prototype detail screens | Genuine entitlements, level EXP, relationship records and moderation pending |
| Authentication | Sign-in, sign-up, recovery, verification form validation | No live authentication/session, OTP, password handling or account creation |
| Friends and search | Friend/follow/follower/requests tabs and search sample; navigable sections | Accounts, graph, requests, messaging, privacy access control pending |
| Chat/notifications | Chat preview, official support entry, notification categories | Authenticated messaging, delivery, receipts, moderation, push pending |
| Store and bag | Categories, responsive listings, item detail sheets, empty states | Real prices/stock/item ownership, purchase and equip transactions pending |
| Recharge | Six existing coin packs -> available agent picker -> order and chat UX | Verified merchant settlement, official centrally priced bundles, transactional balances pending |
| Agency | Unified agency hub, agent/staff/supervisor/management prototype screens | Backend-enforced roles, onboarding workflow, employee approval and treasury pending |
| Payroll, complaints, ratings | Interactive local prototypes with policy messages | Audited immutable records, evidence, decisions, appeals and settlements pending |
| Help, safety, reporting | FAQ sections, account safety and complaint forms with local input validation | Support cases, private attachments, privacy policy and real account security pending |
| Admin dashboard | Basic frontend management visibility/role preview | Separate authenticated operational admin dashboard and RLS enforcement pending |
| Publisher/root visual master | Original `index.html` remains untouched | Do not replace signed master artifacts; all work lives in `/app/` |

## Required backend integration contracts (must not be replaced with fake success)

1. **Authentication** — secure session and refresh, email/phone verification, rate limits, account recovery, profile privacy, logout-all.
2. **Rooms and live voice** — WebRTC or verified provider transport, seat ownership with atomic claim/release, staff moderation, audio device and music policies, realtime presence, reconnect and race-condition handling.
3. **Treasury and coins** — owner-only wallet funding, append-only double-entry ledger, integer values, operation idempotency keys, server-side validation and audit. No frontend authority to mint or transfer balance.
4. **Recharge orders** — fixed wholesale/retail price source, approved agents/accepted recipient accounts, agency availability and staff assignment, 15-minute acceptance/payment deadlines, paid-late escalation, escrow/reservation state and conflict-safe order updates.
5. **Agency HR** — staff consent, one active agency, separate charge privileges, owner vs supervisor visibility, salary confidentiality, suspension, controlled dismissal, reinstatement and transfer reviews.
6. **Complaints and support** — authorized access, evidence upload to private storage, appeals, response tracking, privacy redaction and abuse prevention.
7. **Ratings** — one per verified completed eligible purchase; receipt verification for direct-ID sale; immutable revision history and moderated agency responses; only the public agency aggregate is shown to customers.
8. **Gifts/diamonds/monthly settlement** — verified coin debit and diamond/commission credit, lucky-gift odds approved by management, freeze monthly balances only *after* durable financial liability reports are recorded, no silent forfeiture of lawful entitlements.
9. **Store/inventory/VIP** — server-defined prices, inventory entitlements, equip exclusivity, expirations, reversals and anti-double-spend protections.
10. **Admin and audit** — separate role-scoped dashboard with explicit owner protections, 2FA as appropriate, all money-changing actions logged, approved SQL policies and threat review.
11. **Realtime & notification events** — order updates, chats, room changes, reports, wallet history; subscriptions scoped by authenticated member ID/role, inaccessible to third parties.
12. **Launch/legal** — country-specific review of Google Play digital-goods/payment rules, privacy/data retention, user reporting and employee contractual obligations.

## UI implementation map

- `app/frontend-finish.js`: new and upgraded route markup, controls, form validation and navigation for account recovery, social lists, bags, store, alerts, help, search, safety and report review.
- `app/frontend-finish.css`: presentation in approved Bloom visual language; no decorative components removed.
- `app/agency-hub.js`: agency/recharge prototype and internal role selection for reviewer testing only (not authentication).
- `app/bloom-signature.css`: approved identity and detailed controls; unchanged visual foundation.
- `app/room-ui-enhancements.js`: voice-room preview interactions; not a proof of real audio.
- `tests/frontend-finish-browser.cjs`: browser acceptance of UI journeys.
- `tests/royal-browser.cjs`, `tests/agency-flow-browser.cjs`, `tests/bloom-design-browser.cjs`: regressions for rooms, VIP, packs and agency routes.

## Non-negotiable frontend acceptance

- Preserve **all** microphone seats, VIP and CP embellishments, gift/seat animation containers, overlays, ribbons and full visual order. Do not introduce minimize/hide for decorative elements to boost performance without owner approval.
- All actionable buttons lead to meaningful UI response. If the backend is unavailable, the UI must explicitly say *preview/unavailable* and never claim account creation, successful charging, payroll payment, or a completed cash transaction.
- Verify mobile widths 350–440px, RTL text, touch targets, keyboard/overlay behavior, accessibility labels, modal close, critical empty/error/loading states, and consistent history/back navigation.
- Financial prices/agency customer bank or wallet details must never be fabricated.
- Do not ship live payment, payroll, coin minting, staff permissions, or voice to production until backend integration and end-to-end permission tests pass.

## Release readiness

**Frontend interactive acceptance and automated browser checks do not establish 100% product completion.** Before starting a real beta, perform backend integration, manual testing on Android hardware, accessibility and performance profiling, screen audits with genuine data, and critical security checks.
