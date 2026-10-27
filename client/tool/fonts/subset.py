#!/usr/bin/env python3
"""Reproducible Jiabu font subsets; run only on the build host, never CI.

From client/ (Python 3.8+, install tool/fonts/requirements.txt in a venv):
  nice -n 19 ionice -c3 python3 tool/fonts/subset.py --cache-dir /tmp/jiabu-font-cache
  nice -n 19 ionice -c3 python3 tool/fonts/subset.py --cache-dir /tmp/jiabu-font-cache --offline
  JIABU_FONT_MIRROR=https://proxy.example/ nice -n 19 ionice -c3 python3 tool/fonts/subset.py --cache-dir /tmp/jiabu-font-cache

Preload the six verified source/license files as <cache>/<sha256> (no extension).
A cache hit is always verified. --offline forbids all downloads. The mirror is
an exact prefix: mirror + ORIGINAL_COMPLETE_URL. sources.json stays unchanged.
Only one heavy task may run on jiabu-build at a time; budget tools + files 40GB.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = ROOT / "packages/jiabu_design/assets/fonts"


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def mirror_url(url, mirror=None):
    return (os.environ.get("JIABU_FONT_MIRROR", "") if mirror is None else mirror) + url


def cached_source(spec, cache_dir, offline=False):
    expected = spec["sha256"]
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise ValueError("Invalid SHA-256: " + expected)
    cache_dir = Path(cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    target = cache_dir / expected
    if target.exists():
        if digest(target) != expected:
            raise ValueError("Corrupt cache entry: " + str(target))
        return target
    if offline:
        raise FileNotFoundError("Offline cache miss: " + str(target))
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=cache_dir, delete=False) as output:
            temporary = Path(output.name)
            with urllib.request.urlopen(mirror_url(spec["url"]), timeout=120) as source:
                while True:
                    block = source.read(1024 * 1024)
                    if not block:
                        break
                    output.write(block)
        if digest(temporary) != expected:
            raise ValueError("SHA-256 mismatch: " + spec["url"])
        temporary.replace(target)
        return target
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def select_values(value, path):
    """Paths are arrays, e.g. [categories, *, aliases, *]; '*' visits arrays/maps."""
    if not path:
        if isinstance(value, str):
            return [value]
        raise ValueError("JSON selection must end at a string")
    key, tail = path[0], path[1:]
    if key == "*":
        children = value.values() if isinstance(value, dict) else value
        if not isinstance(value, (dict, list)):
            raise ValueError("Wildcard requires object or array")
        return [text for child in children for text in select_values(child, tail)]
    if isinstance(value, list):
        return select_values(value[int(key)], tail)
    return select_values(value[key], tail)


def message_text(text):
    # C1 ARB messages use simple named placeholders (no ICU plurals/selects).
    # Reject richer ICU instead of silently extracting a different character set.
    if re.search(r"\{\s*\w+\s*,", text):
        raise ValueError("Add explicit ICU handling before using plural/select sources")
    return re.sub(r"\{\w+\}", "", text)


def read_sources(config, root=ROOT):
    # JSON is a YAML subset; PyYAML also permits normal YAML when extended later.
    import yaml
    document = yaml.safe_load(Path(config).read_text(encoding="utf-8"))
    records = []
    for source in document["sources"]:
        path = Path(root) / source["file"]
        if source["format"] == "text":
            texts = [line for line in path.read_text(encoding="utf-8").splitlines()
                     if line.strip() and not line.lstrip().startswith("#")]
        elif source["format"] == "json":
            data = json.loads(path.read_text(encoding="utf-8"))
            if "keyPrefix" in source:
                texts = [message_text(value) for key, value in data.items()
                         if not key.startswith("@")
                         and key.startswith(source["keyPrefix"])
                         and isinstance(value, str)]
            else:
                texts = select_values(data, source["path"])
        else:
            raise ValueError("Unknown source format: " + source["format"])
        chars = {ord(char) for text in texts for char in text if not char.isspace()}
        records.append((source, chars))
    return records


def gb2312_level1():
    chars = set()
    for high in range(0xB0, 0xD8):
        for low in range(0xA1, 0xFF):
            try:
                chars.add(ord(bytes([high, low]).decode("gb2312")))
            except UnicodeDecodeError:
                pass
    assert len(chars) == 3755
    return chars


def rename_hand(font):
    names = {1: "JiabuHand", 2: "Medium", 3: "JiabuHand-Medium-1.530",
             4: "JiabuHand Medium", 6: "JiabuHand-Medium",
             16: "JiabuHand", 17: "Medium"}
    # Keep copyright and license IDs intact, replace all platform family records.
    table = font["name"]
    table.names = [record for record in table.names if record.nameID not in names]
    for name_id, value in names.items():
        table.setName(value, name_id, 3, 1, 0x409)
        table.setName(value, name_id, 1, 0, 0)


def build_font(source, output, codepoints, kind):
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
    font = TTFont(source, recalcTimestamp=False)
    if kind == "numerals":
        font = instantiateVariableFont(font, {"wght": 600}, inplace=True)
    available = set(font.getBestCmap())
    if kind == "numerals":
        # Latin-1 contains controls and some unassigned glyphs; retain all that
        # the upstream supplies, while enforcing essential monetary characters.
        essential = set(map(ord, "0123456789.,:¥−"))
        missing = essential - available
        codepoints = codepoints & available
    else:
        missing = codepoints - available
    if missing:
        raise ValueError("Missing upstream glyphs in {}: {}".format(
            kind, " ".join("U+{:04X}".format(c) for c in sorted(missing))))
    if kind == "hand":
        rename_hand(font)
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14, 16, 17]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.hinting = False
    options.recalc_timestamp = False
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=sorted(codepoints))
    subsetter.subset(font)
    font["head"].created = font["head"].modified = 2082844800
    font.recalcTimestamp = False
    font.save(output, reorderTables=True)
    font.close()
    with TTFont(output, recalcTimestamp=False) as result:
        actual = set(result.getBestCmap())
    if codepoints - actual:
        raise ValueError("Subsetting lost requested characters")
    return {"codepoint_count": len(actual), "bytes": output.stat().st_size,
            "sha256": digest(output)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=Path, required=True)
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    import fontTools
    if fontTools.__version__ != "4.55.8":
        raise SystemExit("Install the pinned tool/fonts/requirements.txt first")
    specs = json.loads((ROOT / "tool/fonts/sources.json").read_text())["fonts"]
    records = read_sources(ROOT / "tool/fonts/char_sources.yaml")
    points = {kind: set() for kind in specs}
    for source, chars in records:
        for target in source["targets"]:
            points[target].update(chars)
    points["numerals"] = set(range(0x20, 0x100)) | set(map(ord,
        "‐‑‒–—‘’“”•…−€¥×"))
    points["serif"] |= gb2312_level1() | set(range(0x20, 0x7F))
    args.output_dir.mkdir(parents=True, exist_ok=True)
    licenses = args.output_dir.parent / "licenses"
    licenses.mkdir(parents=True, exist_ok=True)
    # Generate into staging so a failed glyph/download check leaves no partial set.
    manifest = {"fonttools": fontTools.__version__, "fonts": {}}
    with tempfile.TemporaryDirectory(dir=args.output_dir.parent) as staging:
        staging = Path(staging)
        for kind, spec in specs.items():
            source = cached_source(spec, args.cache_dir, args.offline)
            license_source = cached_source(spec["license"], args.cache_dir, args.offline)
            output = staging / spec["output"]
            entry = build_font(source, output, points[kind], kind)
            entry.update({"source_sha256": spec["sha256"],
                          "source_url": spec["url"], "weight": spec["weight"]})
            manifest["fonts"][spec["output"]] = entry
            (staging / spec["license"]["output"]).write_bytes(license_source.read_bytes())
        for spec in specs.values():
            (staging / spec["output"]).replace(args.output_dir / spec["output"])
            name = spec["license"]["output"]
            (staging / name).replace(licenses / name)
    (args.output_dir / "subset_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")


if __name__ == "__main__":
    main()
