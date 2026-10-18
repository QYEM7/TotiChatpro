# Delivery status — 2026-10-19

Source: https://github.com/mrbalmain11-star/- (approved UI reference)
Implementation branch: feature/approved-ui-flutter-v1
Database: rziaedugbdwefbefcxjt (Staging only)

- Added LiveKit Flutter transport using token minted by the existing phase2-voice-token Edge Function.
- Uses the existing phase2_room_set_muted RPC for microphone permission.
- Keeps audio session in memory while a voice room is minimized and explicitly disconnects on leave/sign out.
- Google OAuth uses web callback URL on browser and deep link for Android; **redirect allowlist must be configured** for the published preview.
- Builds Android debug APK and Flutter Web preview via GitHub Actions. A build is not a validated two-device voice session.
- Attempts GitHub Pages deployment of the approved-source Flutter preview; deployment may be blocked by Pages configuration.
- No production changes, no auto database migrations.
- Current Flutter UI is incomplete relative to all 33 source components; screenshots must be verified before launch.
- The APK uses a public Staging publishable key, never a service-role or database secret.
