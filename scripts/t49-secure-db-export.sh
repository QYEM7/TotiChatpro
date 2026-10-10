#!/usr/bin/env bash
# T49 opt-in encrypted logical DB export, not a restore or an APK release.
set -eo pipefail
umask 077
fail(){ echo "T49 export BLOCKED: $*" >&2; exit 2; }
[[ "$T49_EXPORT_APPROVED" == "YES" ]] || fail "explicit approval flag required"
[[ "$T49_PROJECT_REF" == "sqedsnyvjblvbjbizcay" ]] || fail "wrong project"
[[ "$PGHOST" == "db.sqedsnyvjblvbjbizcay.supabase.co" ]] || fail "wrong database host"
[[ "$PGPORT" == "5432" && "$PGDATABASE" == "postgres" && "$PGUSER" == "postgres" ]] || fail "wrong DB connection"
[[ "$PGSSLMODE" == "verify-full" ]] || fail "database TLS verification required"
[[ -n "$PGPASSWORD" || -n "$PGPASSFILE" ]] || fail "trusted database authentication required"
[[ "$T49_BACKUP_DIR" == /* && -d "$T49_BACKUP_DIR" && ! -L "$T49_BACKUP_DIR" ]] || fail "absolute private backup directory required"
backdir="$(cd "$T49_BACKUP_DIR" && pwd -P)"
repo="$(pwd -P)"
[[ "$backdir" != "$repo" && "$backdir" != "$repo/"* ]] || fail "never write backup inside repository"
mode="$(stat -c %a "$backdir")"
[[ "$mode" =~ ^[0-7]{3,4}$ ]] || fail "invalid backup directory permissions"
(( (8#$mode & 077) == 0 )) || fail "backup directory must deny group/other access"
[[ "$AGE_RECIPIENT" =~ ^age1[a-z0-9]{45,}$ ]] || fail "age public encryption recipient required"
for bin in pg_dump age sha256sum mktemp stat date; do command -v "$bin" >/dev/null 2>&1 || fail "missing $bin"; done
if [[ -n "$PGPASSFILE" ]];then
 [[ -f "$PGPASSFILE" ]] || fail "passfile missing"
 mode="$(stat -c %a "$PGPASSFILE")"
 [[ "$mode" =~ ^[0-7]{3,4}$ ]] || fail "passfile permissions invalid"
 (( (8#$mode & 077) == 0 )) || fail "passfile must deny group/other access"
fi
tmpdir="$(mktemp -d "$backdir/.t49-stage-XXXXXXXX")"
cleanup(){ rm -f -- "$tmpdir/export.age"; rmdir -- "$tmpdir" 2>/dev/null || true; }
trap cleanup EXIT
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
final="$backdir/t49-totichatpro-$stamp.dump.age"
[[ ! -e "$final" && ! -e "$final.sha256" ]] || fail "refuse overwrite"
# Stream directly into encryption; never create an unencrypted dump file.
pg_dump --format=custom --no-owner --no-acl --dbname=postgres |
 age -r "$AGE_RECIPIENT" -o "$tmpdir/export.age"
[[ -s "$tmpdir/export.age" ]] || fail "encrypted export empty"
mv -n -- "$tmpdir/export.age" "$final"
[[ -s "$final" ]] || fail "encrypted export not saved"
sha256sum "$final" > "$final.sha256"
chmod 600 "$final" "$final.sha256"
echo "T49 encrypted DB export created; inspect privately: $final"
echo "T49 RESTORE NOT VERIFIED, Storage object bytes NOT backed up, beta release still BLOCKED."
