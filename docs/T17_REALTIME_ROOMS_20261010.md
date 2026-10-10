# T17 Realtime room updates (new migration pending, 2026-10-10)

Adds pending `20261010133600_t17_realtime_rooms.sql` to include existing
RLS-protected room, membership and message tables in the Supabase Realtime
publication. No public or anonymous room grants added.

Frontend uses Supabase's official Phoenix v1 WebSocket protocol directly,
so it works inside the approved offline Android WebView without a CDN or
additional JS package. Uses the real authenticated JWT for subscription and
sends heartbeats/access_token updates. A Realtime event is only a signal to
re-fetch current rows through existing Supabase RLS-protected REST APIs; no
event records are written directly into DOM or trusted as authoritative.

On signed-out, user-switched or hidden state: close/dispose sockets, never
carry events into another account. Backoff reconnection is bounded at 30s.
Existing polling each 7.5s and foreground/online immediate refresh remain
as network fallback. No LiveKit transport or audio is altered.

CI runs a real local JWT-authenticated WebSocket subscription for room
creation by a second GoTrue user; negative SQL tests ensure rooms/messages
retain RLS. Production migration is NOT deployed until full backup/staging
and release review. Live app will continue polling safely until then.

Verified protocol: https://supabase.com/docs/guides/realtime/protocol
Postgres changes: https://supabase.com/docs/guides/realtime/postgres-changes
