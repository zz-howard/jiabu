#!/usr/bin/env bash
# Build-host only. No pub/code generation is run by this script.
# C2/C3/C4 share bootstrap sessions. C4 covers space invitation/transfer/leave
# and real personal-key tool access/revocation; no additional server process.
set -euo pipefail

: "${JIABU_IT_PG_PORT:?set an unused PostgreSQL port}"
: "${JIABU_IT_HTTP_PORT:?set an unused HTTP port}"
: "${JIABU_IT_HTTP_PORT_B:?set another unused HTTP port}"
: "${JIABU_IT_DATA_DIR:?set a directory for disposable integration-test runs}"
: "${JIABU_IT_SERVER_REF:?set a locally available master commit/ref}"
: "${JIABU_IT_AI_PORT:?set an unused loopback fake-upstream port}"
: "${CARGO_TARGET_DIR:?set the build-host Cargo target directory}"

for port in "$JIABU_IT_PG_PORT" "$JIABU_IT_HTTP_PORT" "$JIABU_IT_HTTP_PORT_B" "$JIABU_IT_AI_PORT"; do
  [[ $port =~ ^[0-9]+$ && $port -gt 1024 && $port -lt 65536 ]] || {
    printf 'Invalid integration-test port.\n' >&2; exit 2;
  }
done
[[ $JIABU_IT_PG_PORT != "$JIABU_IT_HTTP_PORT" &&
   $JIABU_IT_PG_PORT != "$JIABU_IT_HTTP_PORT_B" &&
   $JIABU_IT_HTTP_PORT != "$JIABU_IT_HTTP_PORT_B" ]] || exit 2

[[ $JIABU_IT_AI_PORT != "$JIABU_IT_PG_PORT" &&
   $JIABU_IT_AI_PORT != "$JIABU_IT_HTTP_PORT" &&
   $JIABU_IT_AI_PORT != "$JIABU_IT_HTTP_PORT_B" ]] || exit 2

CLIENT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REPO_DIR=$(git -C "$CLIENT_DIR" rev-parse --show-toplevel)
SERVER_COMMIT=$(git -C "$REPO_DIR" rev-parse --verify "$JIABU_IT_SERVER_REF^{commit}")
mkdir -p -- "$JIABU_IT_DATA_DIR"
JIABU_IT_RUN_PARENT=$(cd -- "$JIABU_IT_DATA_DIR" && pwd)
RUN_DIR=$(mktemp -d "$JIABU_IT_RUN_PARENT/c2-it.XXXXXXXX")
PG_MODE=none
PG_CONTAINER=
SERVER_PID=
FAKE_AI_PID=
SERVER_PID_B=
PG_TOOLS=${PG_BIN:-"$HOME/dev-tools/pg18/bin"}
if [[ -d $PG_TOOLS ]]; then PG_TOOLS=$(cd -- "$PG_TOOLS" && pwd); fi
mkdir -p -- "$CARGO_TARGET_DIR"
CARGO_TARGET_DIR=$(cd -- "$CARGO_TARGET_DIR" && pwd)
export CARGO_TARGET_DIR

cleanup() {
  local result=$?
  trap - EXIT INT TERM
  if [[ -n $SERVER_PID ]]; then kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; fi
  if [[ -n $SERVER_PID_B ]]; then kill "$SERVER_PID_B" 2>/dev/null || true; wait "$SERVER_PID_B" 2>/dev/null || true; fi
  if [[ -n $FAKE_AI_PID ]]; then kill "$FAKE_AI_PID" 2>/dev/null || true; wait "$FAKE_AI_PID" 2>/dev/null || true; fi
  if [[ $PG_MODE == local ]]; then "$PG_TOOLS/pg_ctl" -D "$RUN_DIR/pgdata" stop -m immediate >/dev/null 2>&1 || true; fi
  if [[ $PG_MODE == docker ]]; then docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true; fi
  if [[ $result -ne 0 ]]; then
    # Server traces can contain test data. Keep them only on the build host;
    # never print them automatically or attach them as CI artefacts.
    printf 'Client C2/C3/C4 integration tests failed; private temporary output: %s\n' "$RUN_DIR" >&2
  else
    rm -rf -- "$RUN_DIR"
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -x $PG_TOOLS/initdb && -x $PG_TOOLS/pg_ctl && -x $PG_TOOLS/psql ]]; then
  [[ $("$PG_TOOLS/postgres" --version) == *' 18.'* ]] || { printf 'PostgreSQL 18 is required.\n' >&2; exit 2; }
  "$PG_TOOLS/initdb" -D "$RUN_DIR/pgdata" --username=postgres --auth=trust >"$RUN_DIR/initdb.log"
  cat >>"$RUN_DIR/pgdata/postgresql.conf" <<CONFIG
listen_addresses = '127.0.0.1'
port = $JIABU_IT_PG_PORT
unix_socket_directories = ''
CONFIG
  PG_MODE=local
  "$PG_TOOLS/pg_ctl" -D "$RUN_DIR/pgdata" -l "$RUN_DIR/postgres.log" -w start >/dev/null
elif [[ -z ${PG_BIN:-} ]] && command -v docker >/dev/null; then
  PG_CONTAINER="jiabu-c2-${RUN_DIR##*/}"
  PG_MODE=docker
  docker run --detach --rm --name "$PG_CONTAINER" \
    -p "127.0.0.1:$JIABU_IT_PG_PORT:5432" \
    -e POSTGRES_HOST_AUTH_METHOD=trust postgres:18 >/dev/null
  for attempt in $(seq 1 60); do
    if docker exec "$PG_CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then break; fi
    sleep 1
  done
else
  printf 'Set PG_BIN to local PostgreSQL 18 binaries (preferred), or provide Docker.\n' >&2
  exit 2
fi

pg_sql() {
  local db=${PG_DB:-postgres}
  if [[ $PG_MODE == local ]]; then
    "$PG_TOOLS/psql" -h 127.0.0.1 -p "$JIABU_IT_PG_PORT" -U postgres -d "$db" -v ON_ERROR_STOP=1 "$@"
  else
    docker exec -i "$PG_CONTAINER" psql -U postgres -d "$db" -v ON_ERROR_STOP=1 "$@"
  fi
}
pg_sql -c 'CREATE DATABASE jiabu_it' >/dev/null
export JIABU_PROVISION_DATABASE_URL="postgresql://postgres@127.0.0.1:$JIABU_IT_PG_PORT/jiabu_it"
export JIABU_OWNER_DATABASE_URL="postgresql://jiabu_owner@127.0.0.1:$JIABU_IT_PG_PORT/jiabu_it"
export JIABU_ADMIN_DATABASE_URL="postgresql://jiabu_admin@127.0.0.1:$JIABU_IT_PG_PORT/jiabu_it"
export JIABU_DATABASE_URL="postgresql://jiabu_app@127.0.0.1:$JIABU_IT_PG_PORT/jiabu_it"
mkdir -p "$RUN_DIR/source"
git -C "$REPO_DIR" archive "$SERVER_COMMIT" server | tar -x -C "$RUN_DIR/source"
cd "$RUN_DIR/source/server"
printf 'Testing server commit %s\n' "$SERVER_COMMIT"
cargo build --locked --manifest-path "$RUN_DIR/source/server/Cargo.toml" \
  -p jiabu-admin-bin -p jiabu-server-bin
ADMIN="$CARGO_TARGET_DIR/debug/admin"
SERVER="$CARGO_TARGET_DIR/debug/server"
"$ADMIN" db init-roles
"$ADMIN" db migrate
export JIABU_IT_USER_A=c2_alex JIABU_IT_USER_B=c2_robin
JIABU_IT_PASSWORD_A=$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')
JIABU_IT_PASSWORD_B=$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')
export JIABU_IT_PASSWORD_A JIABU_IT_PASSWORD_B
printf '%s' "$JIABU_IT_PASSWORD_A" | env USER=c2-it-operator "$ADMIN" user create "$JIABU_IT_USER_A" --password-stdin --space-name '用户A' >"$RUN_DIR/account-a.log"
printf '%s' "$JIABU_IT_PASSWORD_B" | env USER=c2-it-operator "$ADMIN" user create "$JIABU_IT_USER_B" --password-stdin --space-name '用户B' >"$RUN_DIR/account-b.log"
# CLI-created accounts start with a temporary password (403 password_change_required).
# The forced change itself is covered by widget/unit tests; clear the flag here like the server tests do.
PG_DB=jiabu_it pg_sql -c "UPDATE users SET must_change_password = false WHERE username IN ('$JIABU_IT_USER_A', '$JIABU_IT_USER_B')" >/dev/null
# C5: process-scoped opt-in; never route fixture calls to official endpoints.
export JIABU_AI_ALLOW_LOOPBACK_ENDPOINT=1
export JIABU_IT_AI_URL="http://127.0.0.1:$JIABU_IT_AI_PORT"
python3 "$CLIENT_DIR/tool/c5_fake_upstream.py" --port "$JIABU_IT_AI_PORT" >"$RUN_DIR/fake-ai.log" 2>&1 &
FAKE_AI_PID=$!
export JIABU_IT_AI_FIXTURE_DIR="$RUN_DIR"
python3 - <<'C5CONFIG'
import json, os, pathlib, time, urllib.request
root = pathlib.Path(os.environ['JIABU_IT_AI_FIXTURE_DIR'])
base = os.environ['JIABU_IT_AI_URL']
for attempt in range(60):
    try:
        with urllib.request.urlopen(base + '/healthz', timeout=1):
            break
    except OSError:
        time.sleep(1)
else:
    raise SystemExit('Fake upstream did not become healthy')
credentials = root / 'synthetic-oauth.json'
credentials.write_text(json.dumps({'revision': 1, 'usable': True, 'credentials': {
    'access_token': 'synthetic-access', 'refresh_token': 'synthetic-refresh',
    'client_id': 'oaiapp_fake', 'account_id': 'synthetic-account',
    'expires_at': int(time.time()) + 86400, 'host_id': '00000000-0000-0000-0000-000000000000'}}))
credentials.chmod(0o600)
(root / 'provider.json').write_text(json.dumps({'id': 'c5-fixture', 'kind': 'siwc',
    'base_url': base, 'billing': 'subscription', 'secret_source': 'file:' + str(credentials),
    'enabled': True, 'version': 1}))
(root / 'model.json').write_text(json.dumps({'id': '019a0000-0000-7000-8000-000000000005',
    'provider_id': 'c5-fixture', 'model': 'synthetic-model', 'structured': 'tool_call',
    'vision': True, 'context_tokens': 128000, 'enabled': True}))
C5CONFIG
if ! "$ADMIN" provider add --file "$RUN_DIR/provider.json" >"$RUN_DIR/provider-add.log" 2>&1; then
  printf '服务端尚不支持 loopback 测试端点\n' >&2
  exit 1
fi
"$ADMIN" model add --file "$RUN_DIR/model.json" >"$RUN_DIR/model-add.log"
"$ADMIN" route set chat 019a0000-0000-7000-8000-000000000005 >"$RUN_DIR/route-chat.log"
"$ADMIN" route set chat_vision 019a0000-0000-7000-8000-000000000005 >"$RUN_DIR/route-vision.log"
export JIABU_DATA_DIR="$RUN_DIR/blobs"
export JIABU_MIGRATE_ON_START=false
JIABU_LISTEN_ADDR="127.0.0.1:$JIABU_IT_HTTP_PORT" "$SERVER" >"$RUN_DIR/server-a.log" 2>&1 &
SERVER_PID=$!
JIABU_LISTEN_ADDR="127.0.0.1:$JIABU_IT_HTTP_PORT_B" "$SERVER" >"$RUN_DIR/server-b.log" 2>&1 &
SERVER_PID_B=$!
export JIABU_IT_URL="http://127.0.0.1:$JIABU_IT_HTTP_PORT/"
export JIABU_IT_URL_B="http://127.0.0.1:$JIABU_IT_HTTP_PORT_B/"
python3 - <<'PY'
import os, time, urllib.request
for key in ('JIABU_IT_URL', 'JIABU_IT_URL_B'):
    for attempt in range(60):
        try:
            with urllib.request.urlopen(os.environ[key] + 'healthz', timeout=1) as response:
                if response.status == 200:
                    break
        except OSError:
            pass
        time.sleep(1)
    else:
        raise SystemExit('Integration-test server did not become healthy')
PY
kill -0 "$SERVER_PID" "$SERVER_PID_B"
# C3 uses real calendar paths in UTC and Asia/Shanghai. If either space is
# within ten minutes of midnight, wait across that boundary before recording
# dates. Never alter plan dates or records in PostgreSQL.
# Wait until neither test time zone is within 10 minutes of midnight, then
# record each zone's date. Uses date(1) so the host needs no tz database module.
c3_seconds_to_midnight() {
  local h m s
  read -r h m s < <(TZ=$1 date +'%-H %-M %-S')
  echo $((86400 - h * 3600 - m * 60 - s))
}
while :; do
  c3_wait=0
  for c3_zone in UTC Asia/Shanghai; do
    c3_left=$(c3_seconds_to_midnight "$c3_zone")
    if ((c3_left < 600)); then c3_wait=$((c3_left + 1)); fi
  done
  ((c3_wait == 0)) && break
  sleep $((c3_wait < 60 ? c3_wait : 60))
done
JIABU_IT_SPACE_DATE_UTC=$(TZ=UTC date +%F)
JIABU_IT_SPACE_DATE_SHANGHAI=$(TZ=Asia/Shanghai date +%F)
export JIABU_IT_SPACE_DATE_UTC JIABU_IT_SPACE_DATE_SHANGHAI
printf 'C3 space dates: UTC=%s; Asia/Shanghai=%s\n' "$JIABU_IT_SPACE_DATE_UTC" "$JIABU_IT_SPACE_DATE_SHANGHAI"
cd "$CLIENT_DIR/app"
flutter test --tags server --run-skipped
