#!/usr/bin/env bash
set -euo pipefail

readonly PG_BIN="${JIABU_TOOLS_DIR:-$HOME/dev-tools}/pg18/bin"
readonly DB_ROOT="${JIABU_DEV_DB_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/jiabu/pg18}"
readonly DB_DATA="$DB_ROOT/data"
readonly DB_PORT="${JIABU_DEV_DB_PORT:-55432}"
readonly PASSWORD_FILE="$DB_ROOT/password"
readonly AUTH_READY="$DB_ROOT/scram-ready"

[[ "$DB_PORT" =~ ^[0-9]{1,5}$ ]] && ((10#$DB_PORT > 0 && 10#$DB_PORT < 65536)) || {
  printf 'JIABU_DEV_DB_PORT must be between 1 and 65535.\n' >&2
  exit 1
}

read_password() {
  [[ -f "$PASSWORD_FILE" ]] || {
    printf 'Development database password is missing; run dev-db.sh start first.\n' >&2
    exit 1
  }
  chmod 600 "$PASSWORD_FILE"
  password=$(cat "$PASSWORD_FILE")
  [[ "$password" =~ ^[[:xdigit:]]{64}$ ]] || {
    printf 'Invalid development database password file: %s\n' "$PASSWORD_FILE" >&2
    exit 1
  }
}

database_url() {
  read_password
  printf 'postgresql://jiabu:%s@127.0.0.1:%s/jiabu_dev\n' "$password" "$DB_PORT"
}

case "${1:-}" in
  start)
    [[ -x "$PG_BIN/initdb" && -x "$PG_BIN/pg_ctl" && -x "$PG_BIN/postgres" ]] || {
      printf 'PostgreSQL is missing; run server/tool/build-host/setup.sh on the build host.\n' >&2
      exit 1
    }
    [[ $(id -u) -ne 0 ]] || {
      printf 'Run dev-db.sh as a regular user; PostgreSQL refuses root.\n' >&2
      exit 1
    }
    umask 077
    mkdir -p "$DB_ROOT"
    chmod 700 "$DB_ROOT"
    if [[ ! -f "$PASSWORD_FILE" ]]; then
      # Hex encoding is URL-safe and safe to use as an SQL string literal.
      od -v -An -N32 -tx1 /dev/urandom | tr -d ' \n' > "$PASSWORD_FILE"
      printf '\n' >> "$PASSWORD_FILE"
      # A previous cluster may have used trust authentication.
      rm -f "$AUTH_READY"
    fi
    read_password
    new_cluster=false
    if [[ ! -f "$DB_DATA/PG_VERSION" ]]; then
      "$PG_BIN/initdb" -D "$DB_DATA" -U jiabu --encoding=UTF8 \
        --locale=C --auth-local=scram-sha-256 --auth-host=scram-sha-256 \
        --pwfile="$PASSWORD_FILE" >&2
      new_cluster=true
      # This disposable development cluster has no external listener or socket.
      printf "\nlisten_addresses = '127.0.0.1'\nunix_socket_directories = ''\nport = %s\n" \
        "$DB_PORT" >> "$DB_DATA/postgresql.conf"
    fi
    [[ $(cat "$DB_DATA/PG_VERSION") == 18 ]] || {
      printf 'The existing development cluster is not PostgreSQL 18: %s\n' "$DB_DATA" >&2
      exit 1
    }
    if [[ ! -f "$AUTH_READY" ]]; then
      if "$PG_BIN/pg_ctl" -D "$DB_DATA" status >/dev/null 2>&1; then
        "$PG_BIN/pg_ctl" -D "$DB_DATA" -m fast -w stop >&2
      fi
      if [[ "$new_cluster" == false ]]; then
        # Upgrade an existing trust cluster offline, with no network listener.
        # Keep the generated password out of process arguments and command output.
        if ! printf "ALTER ROLE jiabu PASSWORD '%s';\n" "$password" | \
          "$PG_BIN/postgres" --single -D "$DB_DATA" \
            -c password_encryption=scram-sha-256 postgres >/dev/null 2>&1; then
          printf 'Could not configure the development database password offline.\n' >&2
          exit 1
        fi
      fi
      printf '%s\n' \
        'local all all scram-sha-256' \
        'host all all 127.0.0.1/32 scram-sha-256' > "$DB_DATA/pg_hba.conf"
      touch "$AUTH_READY"
    fi
    if ! "$PG_BIN/pg_ctl" -D "$DB_DATA" status >/dev/null 2>&1; then
      "$PG_BIN/pg_ctl" -D "$DB_DATA" -l "$DB_ROOT/postgres.log" \
        -o "-h 127.0.0.1 -p $DB_PORT -c unix_socket_directories=" -w start >&2
    fi
    db_exists=$(PGPASSWORD="$password" "$PG_BIN/psql" -h 127.0.0.1 -p "$DB_PORT" -U jiabu \
      -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname = 'jiabu_dev'")
    if [[ "$db_exists" != 1 ]]; then
      PGPASSWORD="$password" "$PG_BIN/createdb" -h 127.0.0.1 -p "$DB_PORT" -U jiabu jiabu_dev >&2
    fi
    database_url
    ;;
  stop)
    if [[ -f "$DB_DATA/PG_VERSION" ]]; then
      [[ -x "$PG_BIN/pg_ctl" ]] || {
        printf 'Missing PostgreSQL tool: %s/pg_ctl\n' "$PG_BIN" >&2
        exit 1
      }
      if "$PG_BIN/pg_ctl" -D "$DB_DATA" status >/dev/null 2>&1; then
        "$PG_BIN/pg_ctl" -D "$DB_DATA" -m fast -w stop >&2
      fi
    fi
    ;;
  url)
    database_url
    ;;
  *)
    printf 'Usage: %s start|stop|url\n' "$0" >&2
    exit 2
    ;;
esac
