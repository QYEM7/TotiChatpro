# T14 Profile photo — local Auth + WebP upload security

Implemented a NEW, unapplied migration `20261010124900_t14_profile_avatar_storage.sql`.
This migration will be staged and replayed in disposable local CI; it has
**not** been pushed to the production Supabase project.

- Public-avatar Storage bucket `profile-avatars`, images only (`image/webp`),
  2 MB maximum. Public read is intentional: social profile images are visible
  to people with the URL; no passwords, identity docs or secret data should
  be uploaded.
- Per-user upload directory, randomly named images and owner-only Storage
  INSERT/SELECT/DELETE RLS. Storage object owner comes from user JWT.
- The frontend captures legacy preview upload controls only when signed in,
  crops/converts JPG/PNG/WebP to 512x512 WebP (stripping image metadata),
  uploads real bytes and writes the verified new URL to its own RLS profile.
- Image URL is shown from the verified server profile state; no success toast
  until server confirms the PATCH. The old demo FileReader remains only for
  offline guest visual-preview mode. No artwork, seats or HTML/CSS touched.
- CI uses two isolated real GoTrue users. It verifies owner upload, other-user
  denied upload, owner profile edit, other-user denied edit and public avatar
  HTTP GET. All identities and media are ephemeral local Docker artifacts.

Known limitations: production avatar bucket does not exist until this migration
is safely promoted after T03 staging and T49 backup. Old avatars remain in
Storage for rollback/audit; garbage collection and manual avatar deletion
require separate reviewed operations. Mobile camera-picker and cloud image
availability need real devices. Do not claim real production T14 completion.
