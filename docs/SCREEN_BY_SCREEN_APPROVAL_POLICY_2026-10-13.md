# TotiChat — One Screen at a Time: mandatory acceptance protocol
**Decision approved by owner:** 2026-10-13
**Work branch:** `design/totichat-ui-20261013` from `develop/phase-2`
**Status:** ACTIVE PROCESS; no individual screen approved yet.

## Primary rule
Do NOT implement all routes in one unreviewed batch. Work on exactly **one screen** at a time, plus its necessary subordinate dialogs and shared infrastructure. Start with Google-only Login. No work on the next screen until the owner has *explicitly approved* the present screen AND the present screen's required real tests have passed. An owner approving this **workflow** is not an owner approving the Login screen.

## Workflow for each screen
1. **Inventory / acceptance contract:** list every element, click, state, storage object, API/RPC, access check, device behavior, loading/error/empty state, screenshots and measurable pass/fail assertions. Baseline screenshots and cosmetic details compared with concept board.
2. **Visual implementation:** create mobile-first responsive production-grade HTML/CSS/vector assets; match signed-off image direction while respecting real product rules.
3. **Backend contract connection:** reuse existing Supabase Auth/RLS/API/LiveKit contract; never add fake data or bypass security. For any missing backend, document the gap and keep the action disabled or visibly unavailable.
4. **Tests:** unit/DOM/browser coverage, keyboard/a11y, viewport 360/390/430px, loading/offline/error and denied access; verify real authenticated flows against Staging with an authorized account. For auth, include PKCE callback, replay prevention, invalid callback, logout, session resume/expiry, profile creation, cross-account checks and two-device/manual Android checks where applicable.
5. **Owner preview & report:** provide independent preview URL (only after actual deployment confirmed) or verifiable local HTML artifact; show screenshot comparison, screenshots from actual code render and each failing item, not a staged or AI-generated concept as proof of code output.
6. **Owner decision:** `APPROVE`, `REVISE`, `REJECT`. Explicit approval in a subsequent message is required. `APPROVE` freezes visual baseline; tests must separately pass before moving ahead. `REVISE` loops within same screen; `REJECT` redesigns same screen.

## Per-screen state (independently tracked)
- Visual: `NOT_STARTED` / `DESIGNED` / `OWNER_APPROVED`.
- Interaction: `NOT_STARTED` / `IMPLEMENTED` / `TESTED`.
- Backend: `NOT_STARTED` / `CONTRACT_CONNECTED` / `VERIFIED_STAGING`.
- Device: `NOT_STARTED` / `BROWSER_QA` / `ANDROID_VERIFIED`.
- Owner decision: `AWAITING_REVIEW` / `APPROVE` / `REVISE` / `REJECT`.
Only `OWNER_APPROVED` + required test gates means `READY_TO_ADVANCE`; separate release readiness is not implied.

## Login Screen 01 — definitive spec
- UI: TotiChat + falcon identity, split illustration and sign-in section on wide viewports; one-column layout on Android; light pearl / lavender / gold; no cramped dark UI; safe-area and reduced motion.
- Interactive: **only Google** login. No email/password, no phone, no Apple, no Facebook; no mock login, sample user avatar, fake ID, or automatic random public ID.
- Backend: call the existing `window.TotiPhase2Auth.signInWithProvider('google')` provided by `app/phase2-auth.js`, which uses a Google-only provider check, PKCE challenge and verifier, and callback exchange. Do not reimplement token issuance client-side.
- Session state: real signed-in view only when the adapter verifies an authenticated account; surface failures and allow safe logout. No silent success after popup/redirect.
- OAuth hosting: call Google only from a **staging-approved HTTPS or authorized native callback environment**. A static local visual preview is never a valid proof of OAuth. Redirect URI must be in Supabase Staging allowlist and verified. Do not alter production Auth settings.
- Navigation: only redirect/handoff to app after session verification and explicit owner-approved integration; never land on wrong admin page. Admin Center never appears on Login or Home.
- Security: no service-role key, no tokens in URL logs or GitHub; JWT-based authorization enforced on server. No production writes.
- QA acceptance: visual approval; screen reader/keyboard states; Google on/off; redirect allowed/denied; callback correct/invalid/replayed; session resume/logout and return; account RLS/profile; Android hardware only after explicit approval to build; no APK now.

## Protection invariants
Work on isolated branch. Do not modify `app/index.html`, existing production LiveKit SDK, main branch, real wallet/ledger, salaries, gift configuration, or production/Staging DB without a separate necessary approved and verified migration. No new real data for illustrative design. Staging reading is allowed.

## Release/report example
```text
SCREEN: 01 Google Login
Visual: DESIGNED / OWNER_APPROVED?
Interaction: ...
Backend: ...
Android device: ...
Blocking issues: ...
Evidence: branch + commit + preview URL + test output
Owner decision: [Approve] [Revise] [Reject]
READY_TO_ADVANCE: NO (until real gates pass)
```
