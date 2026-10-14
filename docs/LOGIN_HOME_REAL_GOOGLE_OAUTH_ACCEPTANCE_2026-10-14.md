# TotiChat real Google → new Home acceptance — 2026-10-14

## Decision
**PASS for the owner-observed isolated web preview flow.**
On an actual device the owner completed Google sign-in from the **new Vercel Login** and reported being taken **directly to the new Vercel Home**, without a second Login page or the old Cloudflare application. This is real user acceptance of this specific navigation path, **not** a 100% security signoff for the whole application.

## Read-only Supabase Staging OAuth evidence
Project: `rziaedugbdwefbefcxjt`. Timezone: UTC; Baghdad = UTC+3. SQL queried `auth_logs` during **2026-10-14 14:30–14:39 UTC**. Logged source referer names are categorized and no token or personal user data is reproduced.

| UTC timestamp | Endpoint | HTTP result | Logged referer host category |
|---|---|---|---|
| 14:33:34 | `GET /authorize`, provider `google` | `302` | `NEW_VERCEL` |
| 14:33:38 | `GET /callback` | `302` | `OLD_CLOUDFLARE` |
| 14:33:39 | `POST /token` | `200` | `OLD_CLOUDFLARE` |
| 14:33:39–14:33:41 | `GET /user` (4 entries) | `200` | `OLD_CLOUDFLARE` |

This proves a real Google authorize request originated on the new Vercel review domain, followed closely by successful callback, token, and user requests in Staging. Correlation is **temporal**, not a cryptographic per-request linkage.

**Caveat / diagnostic remaining:** The Callback, token and /user entries retain a `Referer` attributed to the old Cloudflare host. This is not evidence the owner ultimately viewed the old site—indeed the owner's actual new-Home observation contradicts that conclusion—but it prevents asserting all traces of Cloudflare have been eliminated. Investigate if users report another redirect and preserve this field as a diagnostic signal.

## Deployment
Verified `totichat-login-review-20261013.vercel.app` aliases to READY deployment `dpl_7VMPeqyxQWmhpR3LeNqXJYhq4pkd`, sourced from `design/totichat-ui-20261013`.
Public review Home: https://totichat-login-review-20261013.vercel.app/home/?review=home02

## Scope and remaining work
- No change was made to production, original Cloudflare deployment, `main`, `develop/phase-2`, or staging database during this acceptance verification.
- Prior source/browser tests are synthetic backend contract checks; the owner explicitly supplied the real OAuth human-device observation.
- Login visual remains **conditionally owner-approved 90%**; outstanding Google-only provider policy and native Android app-flow tests remain.
- New Home **visual approval** and **real account room creation / voice-room integration** are separate gates. `readyToAdvance=false` for Home screen.
