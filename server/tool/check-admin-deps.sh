#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
tree=$(cargo tree -p jiabu-admin -p jiabu-admin-api -e normal)
if matches=$(printf '%s\n' "$tree" | grep -En '(^|[^[:alnum:]_-])jiabu-(db|chat|agent|storage|api)([[:space:]]|$)'); then
  printf 'Forbidden management dependency (dependency tree line):\n%s\n' "$matches" >&2
  exit 1
fi
