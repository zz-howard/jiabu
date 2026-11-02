#!/usr/bin/env python3
"""Validate app release metadata and assemble publishable artifacts."""

import argparse
import hashlib
import json
import pathlib
import re
import shutil
import sys

VERSION_RE = re.compile(
    r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-beta\.[0-9]+)?)\+([0-9]+)\s*$",
    re.MULTILINE,
)


def fail(message):
    raise ValueError(message)


def load_version(pubspec, tag):
    match = VERSION_RE.search(pubspec.read_text(encoding="utf-8"))
    if not match:
        fail("pubspec version must be x.y.z+build or x.y.z-beta.N+build")
    version, build_text = match.groups()
    if tag != f"app-v{version}":
        fail("tag does not match pubspec version")
    channel = "beta" if "-beta." in version else "stable"
    return version, int(build_text), channel


def load_inputs(pubspec, metadata, tag):
    version, build, channel = load_version(pubspec, tag)
    data = json.loads(metadata.read_text(encoding="utf-8"))
    if not isinstance(data.get("min_server_api"), int) or data["min_server_api"] < 1:
        fail("min_server_api must be a positive integer")
    if not isinstance(data.get("security_force"), bool):
        fail("security_force must be a boolean")
    notes = data.get("notes")
    if not isinstance(notes, dict):
        fail("notes must be an object")
    for locale in ("zh-Hans", "en"):
        if not isinstance(notes.get(locale), str) or not notes[locale].strip():
            fail(f"missing non-empty {locale} release notes")
    return {
        "build": build,
        "version": version,
        "channel": channel,
        "min_server_api": data["min_server_api"],
        "security_force": data["security_force"],
        "notes": {locale: notes[locale].strip() for locale in ("zh-Hans", "en")},
    }


def assemble(args):
    release = load_inputs(args.pubspec, args.metadata, args.tag)
    if not args.apk.is_file():
        fail("release APK does not exist")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    stem = f"jiabu-{release['version']}-{release['build']}-{release['channel']}"
    apk_out = args.output_dir / f"{stem}.apk"
    shutil.copyfile(args.apk, apk_out)
    hasher = hashlib.sha256()
    with apk_out.open("rb") as apk_file:
        for chunk in iter(lambda: apk_file.read(1024 * 1024), b""):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    (args.output_dir / f"{stem}.apk.sha256").write_text(
        f"{digest}  {apk_out.name}\n", encoding="utf-8"
    )
    (args.output_dir / "release.json").write_text(
        json.dumps(release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def parse_args(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--pubspec", type=pathlib.Path, required=True)
    parser.add_argument("--metadata", type=pathlib.Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--apk", type=pathlib.Path)
    parser.add_argument("--output-dir", type=pathlib.Path)
    parser.add_argument("--print-channel", action="store_true")
    return parser.parse_args(argv)


def main(argv=None):
    try:
        args = parse_args(argv)
        if args.print_channel:
            print(load_version(args.pubspec, args.tag)[2])
            return 0
        if args.metadata is None or args.apk is None or args.output_dir is None:
            fail("metadata, apk and output-dir are required when assembling")
        assemble(args)
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f"release_app: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
