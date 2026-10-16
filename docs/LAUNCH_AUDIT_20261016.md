# TotiChat — Release readiness audit (2026-10-16)

This is **not approval to publish**. The audit is based on repository inspections, GitHub Actions browser/source checks and read-only Supabase SQL. Automated fixture tests do not substitute for real-device tests.

## Confirmed
- Source: `QYEM7/TotiChatpro`, branch `develop/phase-2`. `main` and both production data and real wallet balances unchanged.
- Latest app is **Reborn**; the legacy UI was removed from the active build. Google OAuth is the only visible login method.
- Reactivity and security work on 2026-10-16: unique Android PKCE callback, cold-start handling, recovery from native bridge setup errors; room-list failures show a real error rather than invented emptiness; live chat draft preservation; authenticated account-deletion support ticket; no in-app coin reseller checkout prompt.
- Browser/CI source checks passed in the separate Reborn pipeline. Debug Android assembly passed before the latest changes.
- Staging Supabase (`rziaedugbdwefbefcxjt`) is healthy. Its public schema has **50** ordinary tables and required `phase2_*`, `phase3_*`, `phase4_*`, `phase5_*` RPC entry points.
- Read-only authority inspection: Staging's single-owner record is linked; main partner is not linked.

## Hard launch blockers — all must be resolved
1. **Production schema drift.** Production Supabase (`sqedsnyvjblvbjbizcay`) currently lists **31** public tables and is missing critical RPCs including `phase2_room_members_visual`, `phase2_dm_send`, `phase2_dm_inbox`, `phase5_notification_feed`, `phase5_support_action`, `phase5_vip_status`, `phase5_special_id_status`. Do **not** copy Staging user data or wallet balances into production. Before any migration: backup, review differences, apply reviewed *schema-only* changes, verify security, restore drill, and only then production cutover.
2. **Production Owner not linked.** The production `phase3.system_authority` row has `owner_id IS NULL`. Do not perform privileged release/admin operations until identity and ownership are safely provisioned by the authorized Owner.
3. **Android Google OAuth and voice.** A real physical Android Google sign-in and cold-start callback, and microphone/audio join/mute/unmute tests between two real devices, remain unverified.
4. **Financial end-to-end.** Real wallets, idempotent gifts, agency order confirmation, host ledger/salaries and negative-balance constraints must be tested with separate authorized QA accounts, with transaction reversals as applicable. Never test using production real-money accounts.
5. **Feature parity.** New Reborn UI is not complete: musical queue and synchronised playback, owner/agent/host operational tools, extended VIP frames and full administration need real integration and functional QA. A route existing in source is not a complete feature.
6. **Privacy and Google Play.** In-app account-deletion request can open a real support ticket, but an external, functioning public account deletion web resource and an operational deletion workflow are still required. Complete and verify privacy policy, Data Safety form, moderation/abuse and digital-goods payment review. In-app digital coin sales generally require Play Billing or approved country-specific exception; do not add external-payment steering.
7. **Release binary.** Current `com.totichat.beta` build is Debug and Staging-only. Google Play needs a tested production-linked, uniquely versioned Android App Bundle (AAB), valid upload signing, Play Console metadata, relevant declarations and Play prelaunch testing. No release keys should be committed.

## Release decision
**NO-GO for Google Play public distribution** until the gates above have objective evidence. A Staging Debug APK can be distributed for limited opt-in testing only; it is neither a production release nor a proof of all functions.

## Recovery
UI previous snapshot: `backup/frontend-before-rebuild-20261016`. Do not modify its commit history.
