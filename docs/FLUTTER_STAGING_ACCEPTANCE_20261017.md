# TotiChat Flutter — staged acceptance checklist (2026-10-17)

This checklist records real unfinished acceptance gates, **not simulated passes**.

## Environment
- GitHub repo `QYEM7/TotiChatpro`, isolated branch `rebuild/flutter-v1`.
- Supabase Staging `rziaedugbdwefbefcxjt`. The production project, `main`, and `develop/phase-2` are excluded.
- No APK/AAB, Play Console release, or financial transactions performed by these changes.
- GitHub Actions static analyzer and widget tests are separate from mobile/device tests.

## Software-level checklists
- [ ] Google OAuth on a real Android phone, including `com.totichat.next://auth/callback`, re-auth, returning app from background and account change.
- [ ] Two verified Google accounts join same room on two phones, test active microphones, speaker/earpiece/Bluetooth, echo, mute, kick, reconnect, low network and seat takeover.
- [ ] Enter room, minimize, browse Home/Explore/DM, restore, confirm no ghost member, disconnect exactly once on explicit exit; kill app then confirm server expiry clean-up.
- [ ] Verify fixed 15-seat layout at common small Android sizes and keyboard overlay; verify image/name/level/seat gift count.
- [ ] Real room invitation accepted once; blocked or invalid token cannot enter private room.
- [ ] Gifts: test recipient seated, allowed quantities 1/7/17/77/777, insufficient balance, timed-out request retry, duplicate submit, wallet ledger, chat gift event and global threshold **>=7000**.
- [ ] Lucky: verify server policy and actual award history. Keep paid drawing disabled until `approvedOddsPublished` is true, official prize odds are shown and compliant billing is implemented.
- [ ] Coin recharge: actual authorized Staging agent/owner/customer accounts and approved test accounting entries, reference uniqueness, duplicate IDs, rollback, negative balance impossibility, verified receipt, reversal paths.
- [ ] Banner: Owner draft image <=512000 WebP bytes, RLS upload path, publish/archive, Home displays only genuinely published scheduled banners.
- [ ] Host agency: real registrations, review, old-agent release, new-agent acceptance, exceptions only with authorized admin and reasons.
- [ ] Payroll: 22-level activity/target and actual rates **not yet deployed**. Monthly snapshot is evidence only; salaries, commissions and zeroing cannot be considered passed.
- [ ] VIP 1–8 current active store tiers from server; VIP 9–10 require real catalog/assets/rules before purchase. Test CP pair exclusivity and active relationship days.
- [ ] Room music: saved queue only. Shared licensed playback, synchronized timestamp, joining mid-track, moderator controls and local volume not yet implemented.
- [ ] Firestore/FCM notification delivery not verified: foreground/background/killed app, permission and token invalidation.
- [ ] Support/customer service role: banner approval workflow (support can submit, only Owner approves) not in current server API.
- [ ] Account deletion, data retention, external request form and Play Data safety declaration verified.
- [ ] Accessibility, poor network, crash recovery, memory, free-tier quotas, load tests, Play policy and visual acceptance.

## Commercial and safety controls
- Existing package amounts were read from Staging; see `docs/TOTICHAT_COMMERCIAL_PROPOSAL_20261017.md`.
- Proposed commissions are neither server settings nor payroll liabilities until approved in writing.
- Google Play policy: https://support.google.com/googleplay/android-developer/answer/9858738
- No customer-facing in-app steering to off-Play digital-currency purchases without an applicable registered exception.
- Never replace missing production data with fictitious balances, fake banners, fake lucky outcomes or dummy users.

## Sign-off
Acceptance requires recorded outcomes with relevant device model, OS, account scopes, transaction IDs and screenshots/logs. Do not assign a numeric readiness percentage without evidence.
