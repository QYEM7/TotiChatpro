# TotiChat — active Flutter rebuild

The active client is **`flutter_app/` on `rebuild/flutter-v1`**.
`main`, root `index.html`, `app/`, Capacitor and historical preview branches are
not the new Flutter application. Root `npm run build` is intentionally blocked
on this rebuild to prevent packaging the old client.

- Source identity: [`active-client.json`](active-client.json).
- Backend: **Staging `rziaedugbdwefbefcxjt` only**.
- Do not modify `main` or production. No APK/AAB builds or deployment.
- Run client checks: `cd flutter_app && flutter pub get && flutter analyze lib test --no-fatal-infos && flutter test`.
- Run packaging regression: `node --test tests/active-client-packaging.test.mjs`.
- GitHub QA: `.github/workflows/flutter-v1-check.yml`.
- Visual reference must be linked and reviewed before claiming Figma fidelity.
  No Figma URL was found in repository Markdown/JSON during the 2026-10-18 audit.

The historical documentation below describes the former web prototype, not
current Flutter approval, deployment or readiness.

---

# TotiChatpro

**TotiChat** — approved interactive visual prototype (UI/UX master).

### معاينة مباشرة | Live visual preview

**https://qyem7.github.io/TotiChatpro/**

This clean repository preserves the exact approved preview previously reviewed in `jsjsnsnsnsn0-pixel/TotiChat`. Its `index.html` matches `reference/approved-original.html` except for nine image source URL replacements pointing to the local `assets/images/` folder.

The 27 original images and brand assets have been copied to this repository and verified by Git blob hash against `reference/approved-assets.gitsha`.

### First live-data integration: home advertising banner

- **[Open the live-banner integration preview](https://qyem7.github.io/TotiChatpro/app/)** — same approved design; home banner now reads 3 genuine official project notices from the **NEW independent Supabase** backend. If the backend becomes unavailable, no fake ad replaces them.
- **[Technical setup and status](docs/home-banners.md)** — secure SQL migration is APPLIED to new project `sqedsnyvjblvbjbizcay` ONLY. The old Supabase database remains untouched.
- **[10 passing Node.js tests](https://github.com/QYEM7/TotiChatpro/actions/workflows/test-banner-integration.yml)** — validates HTML fidelity, 27 image checksums and ad safety.

### Project status

- ✅ Approved original visual design preserved.
- ✅ Original assets imported and verified.
- ✅ Independent preview deployed using GitHub Pages.
- ⏳ Owner's visual review of the first connected-feature preview (`/app/`).
- ⏳ Production frontend, backend/database, voice chat, transactions, agency systems, Android app.

**The approved root page remains a visual demo.** The `/app/` page now has a real, read-only Supabase-powered promotional carousel, but other features still use prototype data. Never infer that money, chat, voice or accounts are fully operational.

### Non-negotiable rules

1. User-facing application name: **TotiChat**, not `TotiChatpro`.
2. Do not redesign, delete, hide, shrink, or simplify the approved visual details (including seats, VIP frames, effects, gifts, room decorations and event strips) without the owner's specific approval.
3. Build production capabilities against this approved visual master, rather than approximating it with existing app screens.
4. The old repository is an independent backup/reference and must not be changed by work on this repository.
5. Do not connect a real backend or build an APK until the owner visually approves this independent preview.

See [APPROVED_PREVIEW.md](./APPROVED_PREVIEW.md) for the source reference and sign-off process.
