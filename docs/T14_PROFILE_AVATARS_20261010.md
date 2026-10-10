# T14 public avatars, local-only rollout
Only an authenticated owner can create/delete own JPG/PNG/WebP objects in profile-avatars bucket (<=5 MB).
Profile `avatar_url` stores canonical owner-scoped Storage path instead of external URLs.
The existing approved profile photo chooser is reused; selected picture is local until Save uploads it; failure never claims success.
Images are public profile art. SQL fails safely if pre-existing external avatar references need review.
Local SQL and Node tests required. Migration NOT applied on production.
Requires hosted staging/backup before activation.
