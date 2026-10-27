#!/usr/bin/env bash
set -euo pipefail

readonly FLUTTER_VERSION=3.47.8
readonly GRADLE_VERSION=9.8.2
readonly JIABU_JDK_URL="${JIABU_JDK_URL:-https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21%2B9/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21_9.tar.gz}"
readonly JIABU_JDK_SHA256="${JIABU_JDK_SHA256:-8b9b611d917e3dfd8419d3566b5949226f69b052fed7e109c1368add1dfe8711}"
readonly JIABU_ANDROID_COMMAND_TOOLS_VERSION="${JIABU_ANDROID_COMMAND_TOOLS_VERSION:-13114758}"
readonly JIABU_ANDROID_COMMAND_TOOLS_SHA256="${JIABU_ANDROID_COMMAND_TOOLS_SHA256:-7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee}"
readonly JIABU_ANDROID_BUILD_TOOLS_VERSION="${JIABU_ANDROID_BUILD_TOOLS_VERSION:-37.0.0}"
readonly JIABU_ANDROID_PLATFORM="${JIABU_ANDROID_PLATFORM:-android-37.0}"
readonly JIABU_NOTO_REVISION="${JIABU_NOTO_REVISION:-165c01b46ea533872e002e0785ff17e44f6d97d8}"
readonly JIABU_NOTO_SHA256="${JIABU_NOTO_SHA256:-2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b}"
readonly TOOLS_DIR="${JIABU_TOOLS_DIR:-$HOME/dev-tools}"
readonly FLUTTER_DIR="$TOOLS_DIR/flutter/$FLUTTER_VERSION"
readonly JDK_DIR="$TOOLS_DIR/jdk17"
readonly SDK_DIR="$TOOLS_DIR/android-sdk"
readonly GRADLE_DIR="$TOOLS_DIR/gradle/gradle-$GRADLE_VERSION"
readonly FONT_DIR="$TOOLS_DIR/test-fonts"
readonly FONT_FILE="$FONT_DIR/NotoSansCJKsc-Regular.otf"

[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || {
  printf 'This toolchain requires x86_64 Linux.\n' >&2
  exit 1
}
for command in curl sha256sum tar xz unzip python3 git; do
  command -v "$command" >/dev/null || {
    printf 'Missing prerequisite: %s\n' "$command" >&2
    exit 1
  }
done

[[ "$JIABU_ANDROID_COMMAND_TOOLS_VERSION" =~ ^[0-9]+$ ]] || {
  printf 'Android command-line tools archive id must be numeric.\n' >&2
  exit 1
}
[[ "$JIABU_ANDROID_BUILD_TOOLS_VERSION" =~ ^37\.[0-9]+\.[0-9]+$ ]] || {
  printf 'Android build-tools must be a fixed 37.x.y version.\n' >&2
  exit 1
}
[[ "$JIABU_NOTO_REVISION" =~ ^[[:xdigit:]]{40}$ ]] || {
  printf 'Noto Sans CJK SC must use a fixed 40-hex commit.\n' >&2
  exit 1
}

task_tmp=$(mktemp -d)
trap 'rm -rf "$task_tmp"' EXIT
mkdir -p "$TOOLS_DIR" "$TOOLS_DIR/flutter" "$TOOLS_DIR/gradle"

download() {
  curl --fail --location --retry 3 "$1" -o "$2"
}

verify_hash() {
  local archive=$1 expected=$2
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || {
    printf 'Invalid SHA-256 for %s\n' "$archive" >&2
    exit 1
  }
  printf '%s  %s\n' "$expected" "$archive" | sha256sum --check -
}

if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
  flutter_base="${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}"
  flutter_base=${flutter_base%/}
  flutter_archive="stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  download "$flutter_base/flutter_infra_release/releases/$flutter_archive" "$task_tmp/flutter.tar.xz"
  # The official release manifest carries the per-archive SHA-256 as well.
  download "$flutter_base/flutter_infra_release/releases/releases_linux.json" "$task_tmp/flutter-releases.json"
  flutter_hash=$(python3 - "$task_tmp/flutter-releases.json" "$FLUTTER_VERSION" "$flutter_archive" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as manifest:
    releases = json.load(manifest)["releases"]
matches = [release for release in releases
           if release["version"] == sys.argv[2]
           and release["channel"] == "stable"
           and release["archive"] == sys.argv[3]]
if len(matches) != 1:
    raise SystemExit("The fixed Flutter release is missing or ambiguous in the official manifest")
print(matches[0]["sha256"])
PY
  )
  verify_hash "$task_tmp/flutter.tar.xz" "$flutter_hash"
  mkdir -p "$task_tmp/flutter-unpack"
  tar -xJf "$task_tmp/flutter.tar.xz" -C "$task_tmp/flutter-unpack"
  mv "$task_tmp/flutter-unpack/flutter" "$FLUTTER_DIR"
fi

if [[ -f "$JDK_DIR/.jiabu-source-url" ]] && \
  [[ "$(cat "$JDK_DIR/.jiabu-source-url")" != "$JIABU_JDK_URL" ]]; then
  printf 'The installed JDK uses a different pinned URL; choose a fresh JIABU_TOOLS_DIR.\n' >&2
  exit 1
fi
if [[ ! -x "$JDK_DIR/bin/java" ]]; then
  download "$JIABU_JDK_URL" "$task_tmp/jdk.tar.gz"
  verify_hash "$task_tmp/jdk.tar.gz" "$JIABU_JDK_SHA256"
  mkdir -p "$task_tmp/jdk-unpack"
  tar -xzf "$task_tmp/jdk.tar.gz" -C "$task_tmp/jdk-unpack" --strip-components=1
  mv "$task_tmp/jdk-unpack" "$JDK_DIR"
  printf '%s\n' "$JIABU_JDK_URL" > "$JDK_DIR/.jiabu-source-url"
fi
"$JDK_DIR/bin/java" -version 2>&1 | \
  awk 'NR == 1 && /version "17([."]|$)/ { valid = 1 } END { exit !valid }' || {
    printf 'The selected JDK must have major version 17.\n' >&2
    exit 1
  }
export JAVA_HOME="$JDK_DIR"
export ANDROID_HOME="$SDK_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"
export PATH="$FLUTTER_DIR/bin:$JAVA_HOME/bin:$SDK_DIR/cmdline-tools/$JIABU_ANDROID_COMMAND_TOOLS_VERSION/bin:$SDK_DIR/platform-tools:$GRADLE_DIR/bin:$PATH"

readonly COMMAND_TOOLS_DIR="$SDK_DIR/cmdline-tools/$JIABU_ANDROID_COMMAND_TOOLS_VERSION"
if [[ ! -x "$COMMAND_TOOLS_DIR/bin/sdkmanager" ]]; then
  download "https://dl.google.com/android/repository/commandlinetools-linux-${JIABU_ANDROID_COMMAND_TOOLS_VERSION}_latest.zip" \
    "$task_tmp/android-tools.zip"
  # Google includes "latest" in the filename; the numeric archive id is fixed.
  verify_hash "$task_tmp/android-tools.zip" "$JIABU_ANDROID_COMMAND_TOOLS_SHA256"
  unzip -q "$task_tmp/android-tools.zip" -d "$task_tmp/android-tools"
  mkdir -p "$SDK_DIR/cmdline-tools"
  mv "$task_tmp/android-tools/cmdline-tools" "$COMMAND_TOOLS_DIR"
fi

# sdkmanager checks the repository-provided checksums for SDK packages.
# Ignore only yes's SIGPIPE after sdkmanager has read the accepted licenses.
set +o pipefail
yes | "$COMMAND_TOOLS_DIR/bin/sdkmanager" --sdk_root="$SDK_DIR" --licenses >/dev/null
license_status=${PIPESTATUS[1]}
set -o pipefail
((license_status == 0)) || exit "$license_status"
"$COMMAND_TOOLS_DIR/bin/sdkmanager" --sdk_root="$SDK_DIR" \
  'platform-tools' "platforms;$JIABU_ANDROID_PLATFORM" "build-tools;$JIABU_ANDROID_BUILD_TOOLS_VERSION"

if [[ ! -x "$GRADLE_DIR/bin/gradle" ]]; then
  gradle_url="https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip"
  download "$gradle_url" "$task_tmp/gradle.zip"
  download "$gradle_url.sha256" "$task_tmp/gradle.sha256"
  gradle_hash=$(awk 'NR == 1 { print $1 }' "$task_tmp/gradle.sha256")
  verify_hash "$task_tmp/gradle.zip" "$gradle_hash"
  unzip -q "$task_tmp/gradle.zip" -d "$TOOLS_DIR/gradle"
fi

mkdir -p "$FONT_DIR"
if [[ ! -f "$FONT_FILE" ]] || \
  ! printf '%s  %s\n' "$JIABU_NOTO_SHA256" "$FONT_FILE" | sha256sum --check --status -; then
  download "https://raw.githubusercontent.com/notofonts/noto-cjk/$JIABU_NOTO_REVISION/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf" \
    "$task_tmp/NotoSansCJKsc-Regular.otf"
  verify_hash "$task_tmp/NotoSansCJKsc-Regular.otf" "$JIABU_NOTO_SHA256"
  mv "$task_tmp/NotoSansCJKsc-Regular.otf" "$FONT_FILE"
fi
if [[ ! -f "$FONT_DIR/LICENSE" ]]; then
  download "https://raw.githubusercontent.com/notofonts/noto-cjk/$JIABU_NOTO_REVISION/LICENSE" \
    "$task_tmp/noto-LICENSE"
  mv "$task_tmp/noto-LICENSE" "$FONT_DIR/LICENSE"
fi
export JIABU_TEST_FONT="$FONT_FILE"

# Preserve caller-provided PUB_HOSTED_URL and FLUTTER_STORAGE_BASE_URL.
{
  printf 'export JAVA_HOME=%q\n' "$JAVA_HOME"
  printf 'export ANDROID_HOME=%q\n' "$ANDROID_HOME"
  printf 'export ANDROID_SDK_ROOT=%q\n' "$ANDROID_SDK_ROOT"
  printf 'export FLUTTER_ROOT=%q\n' "$FLUTTER_DIR"
  printf 'export JIABU_TEST_FONT=%q\n' "$JIABU_TEST_FONT"
  printf 'export PATH=%q:"$PATH"\n' \
    "$FLUTTER_DIR/bin:$JAVA_HOME/bin:$COMMAND_TOOLS_DIR/bin:$SDK_DIR/platform-tools:$GRADLE_DIR/bin"
} > "$TOOLS_DIR/jiabu-client-env.sh"
printf 'Toolchain ready. Run: source %q\n' "$TOOLS_DIR/jiabu-client-env.sh"
