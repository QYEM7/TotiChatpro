# TotiChat Voice Token Bridge (development)
Date: 2026-10-10.

Old project `bfadhdnudmsggylunhlh` provides a reference `livekit-room` Edge Function using LiveKit server SDK and JWT. Its old members, session IDs and keys were not imported.

New project `sqedsnyvjblvbjbizcay` now has `phase2-voice-token`, with JWT verification enabled. It reads the user's real Supabase identity and room membership through authenticated RLS, then issues a short-lived LiveKit participant token. Publishing permission is granted only to the real seat holder with microphone state unmuted; non-seat users can subscribe only. A missing external LiveKit URL/API key/secret fails with an explicit HTTP 503, not simulated audio.

Migration `phase2_actual_mic_mute` controls changing the user's own mute state through a signed-in RPC. Users cannot unmute without a reserved seat; guest clients cannot call the function.

**Still blocking voice:** Configure a LiveKit Cloud/self-hosted SFU and set secrets on the new Supabase project: `LIVEKIT_URL` (`wss://...`), `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`. Set secrets in the platform dashboard rather than storing them in GitHub or ChatGPT messages. The APK currently has no deployed/verified LiveKit media streaming client, so a room mic seat must not be called working voice yet. Verify real speaking and hearing between 2+ Android devices before inviting external testers.

Supabase Auth SMTP is also needed for registration outside the project team.

Do not release the complete 30-day voice beta until both blockers are solved and device tests pass.
