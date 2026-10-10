# T17 — Phone foreground and offline reconnection

Actual real PostgREST room directory and room-member state are refreshed when
the browser/WebView becomes visible again, restores internet connectivity,
or receives focus. Requests are throttled at most once per 2.5 sec on
foreground transition, and existing 7.5 sec polling remains as a fallback.
Changes never touch room seat decorations, open microphoned room state or
the approved visuals, and only refresh an authenticated user's RLS data.

This is **not** the final T17 socket-based Realtime presence or real SFU
reconnection: presence requires LiveKit provider and two-device tests.
Empty/errored HTTP responses remain differentiated as part of T11 fixes.
No production data changed.
