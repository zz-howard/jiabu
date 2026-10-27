#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cargo run --quiet --bin admin -- openapi export --out "$tmp"
status=0
for document in openapi.json openapi-admin.json; do
  if ! diff -u "openapi/$document" "$tmp/$document"; then
    printf 'OpenAPI differs: openapi/%s. Re-export and review the change.\n' "$document" >&2
    status=1
  fi
done
exit "$status"
