#!/usr/bin/env bash
# T49: LOCAL, unlinked, disposable Supabase only. Never a production backup.
set -euo pipefail
if [[ "${T49_DISPOSABLE_ONLY:-}" != "YES" ]]; then
  echo "::error::T49 requires explicit disposable-only flag"; exit 2
fi
if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" || -n "${SUPABASE_DB_PASSWORD:-}" ||
      -n "${PGHOST:-}" || -n "${DATABASE_URL:-}" ]]; then
  echo "::error::T49 refuses linked Supabase tokens or external Postgres connections"; exit 2
fi
mapfile -t LOCAL_DBS < <(docker ps --format '{{.Names}}' | grep '^supabase_db_' || true)
if (( ${#LOCAL_DBS[@]} != 1 )); then
  echo "::error::T49 expected exactly one local Supabase PostgreSQL Docker container"; exit 2
fi
DB_CONTAINER="${LOCAL_DBS[0]}"
RESTORE_DB="t49_disposable_restore_qa"
SCRATCH_DIR="$(mktemp -d)"
BACKUP_FILE="$SCRATCH_DIR/t49_disposable_custom.dump"
cleanup() {
  docker exec "$DB_CONTAINER" dropdb -U postgres --if-exists --force "$RESTORE_DB" >/dev/null 2>&1 || true
  docker exec "$DB_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -c     'drop schema if exists t49_drill cascade' >/dev/null 2>&1 || true
  rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT

# Distinct account/ledger/entitlement test rows, never real user, wallet or payroll data.
test "$(docker exec "$DB_CONTAINER" psql -X -At -U postgres -d postgres -c   "select count(*) from pg_namespace where nspname='t49_drill'")" = "0" || {
  echo "::error::T49 test schema already exists; refusing to overwrite"; exit 2;
}
docker exec -i "$DB_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres <<'SQL'
create schema t49_drill;
create table t49_drill.wallets(
  account_id text primary key,
  coins bigint not null check(coins>=0)
);
create table t49_drill.ledger(
  id integer primary key,
  account_id text not null references t49_drill.wallets(account_id),
  amount bigint not null check(amount<>0),
  balance_after bigint not null check(balance_after>=0)
);
create table t49_drill.month_entitlements(
  id integer primary key,
  account_id text not null references t49_drill.wallets(account_id),
  period date not null,
  owed_diamonds bigint not null check(owed_diamonds>=0),
  settled boolean not null default false
);
alter table t49_drill.wallets enable row level security;
alter table t49_drill.ledger enable row level security;
alter table t49_drill.month_entitlements enable row level security;
revoke all on schema t49_drill from public,anon,authenticated;
revoke all on all tables in schema t49_drill from public,anon,authenticated;
insert into t49_drill.wallets values('fixture-alice',800),('fixture-bob',400);
insert into t49_drill.ledger values
  (1,'fixture-alice',1000,1000),
  (2,'fixture-bob',200,200),
  (3,'fixture-alice',-200,800),
  (4,'fixture-bob',200,400);
insert into t49_drill.month_entitlements values
  (1,'fixture-alice','2026-09-01',110,false),
  (2,'fixture-bob','2026-09-01',45,false);
SQL

# Custom-format logical dump, including schema, sample rows, constraints and RLS.
# Dump bytes live only in this temporary CI runner and are never uploaded.
docker exec "$DB_CONTAINER" pg_dump -U postgres -d postgres \
  --format=custom --no-owner --no-acl --schema=t49_drill > "$BACKUP_FILE"
test -s "$BACKUP_FILE" || { echo "::error::T49 local pg_dump empty"; exit 1; }
docker exec -i "$DB_CONTAINER" pg_restore --list < "$BACKUP_FILE" | grep -q 'TABLE DATA.*wallets' || {
  echo "::error::T49 backup does not contain wallet rows"; exit 1;
}

# Separate logical database on a disposable local Docker PostgreSQL instance.
docker exec "$DB_CONTAINER" createdb -U postgres -T template0 "$RESTORE_DB"
# Destroy the local SOURCE fixture after snapshot: recovery must not read source.
docker exec -i "$DB_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres <<'SQL'
update t49_drill.wallets set coins=0;
delete from t49_drill.month_entitlements;
SQL
docker exec -i "$DB_CONTAINER" pg_restore -U postgres --exit-on-error \
  --single-transaction --no-owner --no-acl -d "$RESTORE_DB" < "$BACKUP_FILE"

docker exec -i "$DB_CONTAINER" psql -X -v ON_ERROR_STOP=1 -U postgres -d "$RESTORE_DB" <<'SQL'
do $verify$
declare invalid_count integer;
begin
 if (select count(*) from t49_drill.wallets)<>2
   or (select sum(coins) from t49_drill.wallets)<>1200
   or (select count(*) from t49_drill.ledger)<>4
   or (select sum(amount) from t49_drill.ledger)<>1200
   or (select sum(owed_diamonds) from t49_drill.month_entitlements)<>155
   or (select count(*) from t49_drill.month_entitlements where settled)<>0
 then raise exception 'T49 snapshot data/entitlements were not restored';end if;
 select count(*) into invalid_count
 from t49_drill.wallets w
 where (select l.balance_after from t49_drill.ledger l
        where l.account_id=w.account_id order by l.id desc limit 1)<>w.coins;
 if invalid_count<>0 then raise exception 'T49 restored balances and ledger diverged';end if;
 if not (select relrowsecurity from pg_class where oid='t49_drill.wallets'::regclass)
   or not (select relrowsecurity from pg_class where oid='t49_drill.ledger'::regclass)
   or not (select relrowsecurity from pg_class where oid='t49_drill.month_entitlements'::regclass)
 then raise exception 'T49 restored RLS settings absent';end if;
 if has_table_privilege('anon','t49_drill.wallets','SELECT')
   or has_table_privilege('authenticated','t49_drill.month_entitlements','SELECT')
 then raise exception 'T49 restored data access widened';end if;
end $verify$;
select 'PASS T49: isolated pg_dump/pg_restore into separate local DB, 1200 conserved coins, 155 preserved month entitlement diamonds, FK/ledger/RLS verified' as result;
SQL
echo "PASS T49: local-only snapshot/restore drill succeeded; production backup and Storage object recovery remain NOT verified."
