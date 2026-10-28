#!/usr/bin/env bash
set -euo pipefail

readonly CLIENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly IMAGE=ghcr.io/zz-howard/jiabu-flutter-ci:3.47.8-1

command -v docker >/dev/null || {
  printf 'Docker is required to use the fixed golden environment.\n' >&2
  exit 1
}

exec docker run --rm --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp --env PUB_CACHE=/tmp/pub-cache --env TZ=UTC \
  --env PUB_HOSTED_URL --env FLUTTER_STORAGE_BASE_URL \
  --volume "$CLIENT_DIR:/workspace" --workdir /workspace \
  "$IMAGE" bash -euo pipefail -c \
  'flutter pub get; cd app; flutter test --tags golden "$@"' bash "$@"
