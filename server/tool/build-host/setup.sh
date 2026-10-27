#!/usr/bin/env bash
set -euo pipefail

readonly RUST_VERSION=1.99.1
readonly PG_VERSION=18.6
readonly NEXTEST_VERSION=0.9.149
readonly DENY_VERSION=0.20.2
readonly SEA_ORM_CLI_VERSION=2.0.4
readonly AUDIT_VERSION=0.22.2
readonly AUDIT_SHA256=7fb9497f8594b389e5fce5ef9b92db08432996895b2e0c5a0167a69ed445c428
readonly TOOLS_DIR="${JIABU_TOOLS_DIR:-$HOME/dev-tools}"
readonly PG_PREFIX="$TOOLS_DIR/pg18"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export PATH="$CARGO_HOME/bin:$PATH"

for command in curl sha256sum tar bzip2 make gcc bison perl; do
  command -v "$command" >/dev/null || {
    printf 'Missing build prerequisite: %s\n' "$command" >&2
    exit 1
  }
done

task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
mkdir -p "$TOOLS_DIR"

if ! command -v rustup >/dev/null; then
  rustup_root="${RUSTUP_UPDATE_ROOT:-https://static.rust-lang.org/rustup}"
  rustup_url="${rustup_root%/}/dist/x86_64-unknown-linux-gnu/rustup-init"
  curl --fail --location --retry 3 "$rustup_url" -o "$task_tmp/rustup-init"
  curl --fail --location --retry 3 "$rustup_url.sha256" -o "$task_tmp/rustup-init.sha256"
  rustup_hash=$(awk 'NR == 1 { print $1 }' "$task_tmp/rustup-init.sha256")
  [[ "$rustup_hash" =~ ^[[:xdigit:]]{64}$ ]] || {
    printf 'Invalid rustup checksum file: %s.sha256\n' "$rustup_url" >&2
    exit 1
  }
  printf '%s  %s\n' "$rustup_hash" "$task_tmp/rustup-init" | sha256sum --check -
  chmod +x "$task_tmp/rustup-init"
  "$task_tmp/rustup-init" -y --no-modify-path --profile minimal \
    --default-toolchain none
fi
rustup toolchain install "$RUST_VERSION" --profile minimal \
  --component rustfmt --component clippy

install_cargo_tool() {
  local package=$1 binary=$2 version=$3
  shift 3
  if ! "$CARGO_HOME/bin/$binary" --version 2>/dev/null | \
    awk -v wanted="$version" '$2 == wanted { found = 1 } END { exit !found }'; then
    cargo "+$RUST_VERSION" install --locked --force --version "=$version" \
      --root "$CARGO_HOME" "$@" "$package"
  fi
}
install_cargo_tool cargo-nextest cargo-nextest "$NEXTEST_VERSION"
install_cargo_tool cargo-deny cargo-deny "$DENY_VERSION"
# Default features pull async-std/native-tls; entity generation only needs PostgreSQL.
install_cargo_tool sea-orm-cli sea-orm-cli "$SEA_ORM_CLI_VERSION" \
  --no-default-features --features cli,codegen,runtime-tokio-rustls,sqlx-postgres
if ! "$CARGO_HOME/bin/cargo-audit" --version 2>/dev/null | \
  awk -v wanted="$AUDIT_VERSION" '$2 == wanted { found = 1 } END { exit !found }'; then
  audit_url="https://github.com/rustsec/rustsec/releases/download/cargo-audit%2Fv$AUDIT_VERSION/cargo-audit-x86_64-unknown-linux-musl-v$AUDIT_VERSION.tgz"
  curl --fail --location --retry 3 "$audit_url" -o "$task_tmp/cargo-audit.tgz"
  printf '%s  %s\n' "$AUDIT_SHA256" "$task_tmp/cargo-audit.tgz" | sha256sum --check -
  mkdir -p "$task_tmp/cargo-audit" "$CARGO_HOME/bin"
  tar -xzf "$task_tmp/cargo-audit.tgz" -C "$task_tmp/cargo-audit"
  audit_binary=
  for candidate in "$task_tmp/cargo-audit/cargo-audit" "$task_tmp/cargo-audit"/*/cargo-audit; do
    if [[ -f "$candidate" ]]; then
      audit_binary=$candidate
      break
    fi
  done
  [[ -n "$audit_binary" ]] || {
    printf 'The official cargo-audit archive did not contain cargo-audit.\n' >&2
    exit 1
  }
  install -m 755 "$audit_binary" "$CARGO_HOME/bin/cargo-audit"
fi

if [[ ! -x "$PG_PREFIX/bin/postgres" ]] || \
  [[ "$("$PG_PREFIX/bin/postgres" --version)" != "postgres (PostgreSQL) $PG_VERSION" ]]; then
  if ! command -v flex >/dev/null; then
    if [[ ! -x "$TOOLS_DIR/flex/usr/bin/flex" ]]; then
      command -v dpkg-deb >/dev/null || {
        printf 'Missing build prerequisite for user-local flex: dpkg-deb\n' >&2
        exit 1
      }
      ubuntu_mirror="${JIABU_UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"
      flex_url="${ubuntu_mirror%/}/pool/main/f/flex/flex_2.6.4-6.2_amd64.deb"
      curl --fail --location --retry 3 "$flex_url" -o "$task_tmp/flex.deb"
      printf '%s  %s\n' \
        '67e2b65dcfdcb6f50b2a78bbf41c9a7fe5f9659017fb33b81bfb824fbdd23111' \
        "$task_tmp/flex.deb" | sha256sum --check -
      mkdir -p "$TOOLS_DIR/flex"
      dpkg-deb -x "$task_tmp/flex.deb" "$TOOLS_DIR/flex"
    fi
    export PATH="$TOOLS_DIR/flex/usr/bin:$PATH"
    flex --version >/dev/null
  fi
  readonly PG_ARCHIVE="postgresql-$PG_VERSION.tar.bz2"
  readonly PG_URL="https://ftp.postgresql.org/pub/source/v$PG_VERSION/$PG_ARCHIVE"
  curl --fail --location --retry 3 "$PG_URL" -o "$task_tmp/$PG_ARCHIVE"
  curl --fail --location --retry 3 "$PG_URL.sha256" -o "$task_tmp/pg.sha256"
  pg_hash=$(awk 'NR == 1 { print $1 }' "$task_tmp/pg.sha256")
  [[ "$pg_hash" =~ ^[[:xdigit:]]{64}$ ]] || {
    printf 'Invalid PostgreSQL checksum file: %s.sha256\n' "$PG_URL" >&2
    exit 1
  }
  printf '%s  %s\n' "$pg_hash" "$task_tmp/$PG_ARCHIVE" | sha256sum --check -
  tar -xjf "$task_tmp/$PG_ARCHIVE" -C "$task_tmp"
  (
    cd "$task_tmp/postgresql-$PG_VERSION"
    ./configure --prefix="$PG_PREFIX" --without-icu --without-readline
    make -j "${JIABU_BUILD_JOBS:-2}"
    make install
  )
fi

printf 'Installed Rust %s and PostgreSQL %s.\n' "$RUST_VERSION" "$PG_VERSION"
printf 'Add %s/bin and %s/bin to PATH.\n' "$CARGO_HOME" "$PG_PREFIX"
