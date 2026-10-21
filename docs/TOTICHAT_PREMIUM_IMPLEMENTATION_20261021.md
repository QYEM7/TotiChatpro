# Premium Flutter screens — implementation and acceptance matrix

Date: 2026-10-21. Work branch: `feat/premium-flutter-surfaces-20261021`.
Base: `fix/green-ui-auth-handoff-20261021` (green Google OAuth PR #33).
Use for **Staging only**; no `main`, production DB, Play deployment, or mock ledger data.

## New data-backed screens

| Feature from approved concept | Actual implementation | Acceptance gap |
| --- | --- | --- |
| Home and discover | Premium quick access + real public room search, real room covers, designed empty state | Physical UI check and navigation |
| Existing Google green sign-in | Preserved from approved green source | OAuth callback physical check |
| Room / 15 seats | Existing authorized room and LiveKit bridge retained, jade background, real seat gifts | Two-phone live audio, overflow, owner moderation |
| Gift Box popup | Existing server-backed gift send and quantities `1 / 7 / 17 / 77 / 777` retained, jade sheet | Verify correct price & idempotency on phones |
| Room two-action overlay | Blur bottom sheet has only Leave and Minimize; real leave confirmation | Phone navigation |
| Member popup | Real member name/avatar, opens authenticated DM; no fake VIP or counts | Avatar fallback and device QA |
| Messages / DM | Existing server-backed inbox and text-only conversation, mint styling | Two-account DM |
| Wallet | Reads authenticated balance and ledger; **no in-app purchase or made-up cards** | Agent request workflow still not integrated |
| Store | Real active products and server prices; **no fake debit/purchase** | Purchase RPC acceptance / entitlement |
| Notifications | Real private server-generated list; unread filter, no fake alerts | Mark-read action/push delivery |
| CP | Reads accepted active relationships and enabled CP types, no fake couples | Authorized CP creation and XP |
| Agencies | Reads active agencies; no fake agencies/requests | Agent/host application, owner review |
| Room music | Reads authorized playlist metadata only | Real synchronized playback, owner controls |
| Profile editing | Real RLS-backed name and bio with confirmation | Avatar upload and additional fields |
| Room details | Real title, cover, welcome and privacy | Moderator detail / invite flow |
| Admin center | Existing server-side role-gated read-only content restyled | Verify role-specific actions |

## Product consistency safeguards

- The concept illustration contains examples of fictitious user counts, avatars,
  room populations, direct card payments and music playback. **These were not
  copied as operational records or UI promises.**
- The user explicitly requires Google-only login, agent-funded wallets,
  no DM voice messages, fixed 15 seats, a two-action room overlay, global
  real gift events only, and no placeholder wealth/Charm values.
- The UI uses one GreenTheme plus reusable premium surfaces, sections, rows
  and meaningful empty states. Deep-green audio room and sheet maintain
  legibility but all business operations stay on the original repositories.
- Data authorization remains on Supabase with RLS, server RPCs and existing
  idempotency; frontend cards never grant admin, user ID, VIP, or currency.

## Release blockers
- Run `flutter analyze lib test`, `flutter test`, generate Android and
  build real ARM64 Release + Android 14 emulator cold starts.
- Check the actual screenshot and test image/layout against approved board.
- Verify green Google callback on the target phone after account logout/login.
- Run two-phone room audio, gift settlement, wallet receipt and DM tests.
- Correct any failed CI or device test before advancing the draft PR.
- Owner reviews every major screen before launch. No success percentage invented.
