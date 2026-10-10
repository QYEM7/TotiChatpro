# T06 — Durable LiveKit Edge token abuse protection

Added a server-only Upstash Redis REST EVAL (atomic INCR+PEXPIRE of two keys)
to the source of phase2-voice-token: 600 global requests/minute plus
12 requests/minute per HMAC-hashed Authorization header. Denials due to
invalid auth are counted when a bearer header is provided. The same
HMAC key is not reusable by other applications; never store the raw JWT
or Redis token in key names or logs.

Credential requirements BEFORE deploying new Edge function code:
UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN, VOICE_RATE_LIMIT_SALT
(32+ chars, stored ONLY in Supabase Edge Secrets).
A missing/failed Redis configuration fails CLOSED with HTTP 503; excessive
attempts get HTTP 429. The deployed Edge code currently running on the
production Supabase project was NOT modified by this GitHub source commit.
Deliberate approval and service provisioning are necessary to activate it.

Limits: this is not an IP-based DDoS gateway; missing-bearer calls return 401
without consuming a Redis counter. Supabase gateway rate limits and
independent abuse testing are still required. The global limit is a safety
bound for a beta and must be sized under realistic traffic.

The REST API command shape and atomic scripting are based on the Upstash
Redis REST documentation:
https://upstash.com/docs/redis/features/restapi
https://upstash.com/blog/lua-scripting-on-upstash-redis-atomic-operations-over-http
