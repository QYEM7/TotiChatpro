# Selective legacy reference import — 2026-10-10

The owner authorized using the old database as a reference and transferring
important ready-made configuration tables into the independent new backend.
This supersedes the earlier prohibition on importing configuration records,
but does not authorize experimental accounts or balances as live user data.

Source: TotiChat / bfadhdnudmsggylunhlh (read-only).
Target: TotiChatpro / sqedsnyvjblvbjbizcay.
Code: develop/phase-2; main and approved UI reference remain untouched.

## Applied and independently verified

| Table | Imported rows | Purpose |
|---|---:|---|
| gift_categories | 5 | Gift box categories |
| gift_catalog | 12 | Actual gift choices, names, prices and effects |
| store_catalog | 40 | Store options, durations, currencies and reward flags |
| cp_types | 1 | Configured relationship type and presentation |
| recharge_packages | 6 | Agent top-up denominations |
| recharge_reward_tiers | 10 | Recharge reward definitions |
| Total | 74 | Reference configuration only |

Six source/target SQL fingerprints match, including all reference fields.
Recharge package UUIDs and timestamps are regenerated in the target; comparison
uses the price, coin amount and active flag. No foreign records reference those
source UUIDs. A source snapshot is versioned under supabase/reference/catalogs.json.

Every imported table has RLS, authenticated SELECT only, no anonymous access,
and no client INSERT/UPDATE/DELETE grants. Enabled/active configuration is
filtered by SELECT policies. Gift/CP foreign keys and index coverage are retained.
The imported VIP constraint accommodates levels 1–10 rather than inheriting
the old schema's arbitrary maximum of 8. No VIP9/10 records were fabricated.

Three existing banners remain. Zero legacy accounts, room memberships,
wallet balances, transaction history, messages or user-role assignments imported.
Old admin grants were deliberately not copied: they must follow the latest
Owner/main-partner/DB restrictions rather than recreate obsolete permissions.

## Connected interface and fixes

- Live store, recharge, CP and gift choices now read the new database;
  preview mode and the approved root UI retain their original behavior.
- Store filtering/search, safe text rendering, item details, recharge rewards,
  gift category/item selection and actual room-member recipient choices.
- Gift selection does not send. Gift sending and store/top-up execution remain
  disabled until real atomic financial operations and permissions are implemented.
- Existing gold/silver catalog currency codes are preserved; no unsupported
  silver balance is invented or silently converted to coins.
- Cache lifetime is 60 seconds; concurrent reads deduplicate and stale requests
  are rejected after account changes. Failed reads never fall back to seed data.
- Fixed wallet account-switch race: a slow previous account request cannot block
  the next account's wallet or overwrite it.
- Remember-me checkbox reflects existing preference after navigating auth screens.
- Dependency lockfile added; foundation CI uses npm ci.

## Verification

- 42 Node tests pass, including new cache/auth-boundary/error tests and wallet race.
- Live SQL verifies all 74 rows, matching source/target fingerprints, RLS and
  read-only grants; authenticated role sees all currently enabled records.
- Browser regression passes Auth/profile/private invites/chat/logout, native
  startup, official split login, and 36 approved UI routes/15 microphone seats.
- Catalog browser contract exercises 40 products, search/focus, 6 packs,
  10 tiers, CP, recipient/gift selection and malicious database-label escaping.
- Browser backend responses are mocked: these checks do not prove real accounts,
  email delivery, money movement or multi-device audio.

## Remaining release blockers

Google/Apple/Facebook OAuth and SMTP settings are Auth service configuration,
not ordinary public tables. Catalog migration cannot enable those integrations.
The new provider settings continue to control which login buttons are enabled.
LiveKit secrets/infrastructure and physical device audio validation remain needed.

Financial transactions, treasury/agents, gift execution, store entitlements,
VIP/CP relationships, agency payroll/monthly settlement, music and Owner/staff
dashboard are not completed by this reference import.

Security advisor after migration: no new catalog warning; existing 9 authenticated
SECURITY DEFINER room RPC warnings and one intentionally unreadable invitation
table notice remain. Production requires adversarial live-account checks of
those RPCs. Performance advisor shows informational unused indexes on a nearly
empty project; do not delete integrity/FK indexes merely to suppress that notice.

This is completed selective configuration migration and tested frontend
integration, not certification that every application issue is fixed or that
the month-long voice beta is ready.
