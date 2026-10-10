# TotiChat Live Web Preview implementation

Source of truth: QYEM7/TotiChatpro, develop/phase-2.
Production backend: sqedsnyvjblvbjbizcay. Legacy backend: bfadhdnudmsggylunhlh.
The current official Cloudflare Pages site is ONLY a landing page.

This checkpoint introduces scripts/build-live-preview.mjs and deterministic unit tests. It packages the EXACT approved TotiChat frontend and 15-seat UI using the existing Android-safe web builder; the preview-specific copy is forced into live-account mode, carries OAuth callback query intact, and disables the optional synthetic visual sample entry. The approved source UI is unchanged. It can only build against a distinct Supabase STAGING project using public STAGING_SUPABASE_URL and STAGING_SUPABASE_PUBLISHABLE_KEY; the production backend URL is prohibited and source config is never rewritten.

Build: npm ci; npm run build; STAGING_SUPABASE_URL=<isolated> STAGING_SUPABASE_PUBLISHABLE_KEY=<public> node scripts/build-live-preview.mjs
Result: dist-live-preview/ static web app including real Auth/rooms/LiveKit client, assets, no APK. Headers set noindex, no-store for runtime config, and microphone permitted for this origin.

Deployment remains NOT CONFIRMED until Cloudflare Pages token/account connected and an independent staging Supabase project exists. Real user sessions and two-phone voice remain UNVERIFIED. DO NOT reuse old TotiChat database as staging, post real database credentials, create paid services, publish a link prematurely, or relax T48. Cloudflare Pages branch alias target is preview.totichatpro.pages.dev but NOT a verified live URL yet.
