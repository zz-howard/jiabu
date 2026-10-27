#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
: "${DATABASE_URL:?PostgreSQL 18 superuser URL required}"
# Dev/CI only: the same fake role password the test fixtures use (server/tests/support).
role_password=jiabu-test-only
mode=${1:-check}
[[ "$mode" == check || "$mode" == --write ]] || { printf 'Usage: %s [--write]\n' "$0" >&2; exit 2; }
task_tmp=$(mktemp -d)
entity_db="jiabu_entities_$(python3 -c 'import uuid; print(uuid.uuid4().hex)')"
cleanup() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS \"$entity_db\" WITH (FORCE)" >/dev/null
  rm -rf "$task_tmp"
}
trap cleanup EXIT
JIABU_PROVISION_DATABASE_URL="$DATABASE_URL" cargo run --quiet --bin admin -- db init-roles
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "ALTER ROLE jiabu_owner PASSWORD '$role_password'" >/dev/null
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$entity_db\" OWNER jiabu_owner" >/dev/null
export JIABU_ENTITY_DB_NAME="$entity_db" JIABU_ROLE_PASSWORD="$role_password"
entity_owner_url=$(python3 - <<'PY'
import os
from urllib.parse import urlsplit, urlunsplit
url = urlsplit(os.environ['DATABASE_URL'])
host = url.hostname
if ':' in host:
    host = '[' + host + ']'
print(urlunsplit((url.scheme, 'jiabu_owner:' + os.environ['JIABU_ROLE_PASSWORD'] + '@' + host + ':' + str(url.port or 5432), '/' + os.environ['JIABU_ENTITY_DB_NAME'], '', '')))
PY
)
JIABU_OWNER_DATABASE_URL="$entity_owner_url" cargo run --quiet --bin admin -- migrate
# Keep this command identical for initial generation and every CI run.
sea-orm-cli generate entity --database-url "$entity_owner_url" \
  --output-dir "$task_tmp/entities" --with-serde both \
  --date-time-crate chrono --ignore-tables _sqlx_migrations
if [[ "$mode" == --write ]]; then
  # This directory contains generated Rust only; remove stale generated tables too.
  mkdir -p crates/db/src/entity
  while IFS= read -r file; do rm -- "$file"; done < <(find crates/db/src/entity -name '*.rs' -type f)
  cp -R "$task_tmp/entities/." crates/db/src/entity/
else
  # --no-index detects newly generated untracked files as well as changed files.
  git diff --no-index --exit-code -- crates/db/src/entity "$task_tmp/entities"
fi
