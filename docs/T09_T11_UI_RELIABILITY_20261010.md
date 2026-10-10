# T09/T11 — Mobile UI and real interactions audit

Project QYEM7/TotiChatpro. Approved HTML, CSS, artwork, seats and app styling remain untouched.

Fix 1: the phase2Demo URL parameter previously bypassed real auth click handling in the native/explicit live client. Now it is only meaningful outside live mode.
Fix 2: the legacy Royal click capture listener previously entered a fake Games room or hid real room cards when a signed-in user tapped categories. In live mode it leaves actual loaded rooms visible and explicitly reports unavailable backend features.
Fix 3: a failed room-list request was converted to an empty list, which falsely claimed no rooms were open. The UI now announces the error and shows Retry, retaining last-known genuine cards. Account changes and room exit reset stale list-fetch locks.

Verification: Node static contracts + Chromium automated 320,360,390,430,768,1280px widths. Native gate browser verifies sign-in even with an adversarial phase2Demo URL, plus games button remains truthful. Browser requests are intercepted to ensure no real Supabase accounts or wallets are changed.

Browser screenshots and code tests are not sufficient to certify physical IME keyboards, Voice/LiveKit, real OAuth providers or signed Android installation. Keep T09/T11 partial until live E2E acceptance.
