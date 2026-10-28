"""Build-host tool tests: python3 -m unittest discover -s tool/fonts -p 'test_*.py'."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import subset


class FontToolTest(unittest.TestCase):
    def test_mirror_is_exact_prefix(self):
        url = "https://github.com/example/font.ttf"
        self.assertEqual(subset.mirror_url(url, "https://mirror/"),
                         "https://mirror/" + url)
        self.assertEqual(subset.mirror_url(url, ""), url)

    def test_cached_bytes_are_verified_without_downloading(self):
        with tempfile.TemporaryDirectory() as directory:
            spec = {"url": "https://example.invalid/font", "sha256":
                    hashlib.sha256(b"verified").hexdigest()}
            target = Path(directory) / spec["sha256"]
            target.write_bytes(b"verified")
            with patch("urllib.request.urlopen", side_effect=AssertionError("network")):
                self.assertEqual(subset.cached_source(spec, directory), target)
                target.write_bytes(b"corrupt")
                with self.assertRaisesRegex(ValueError, "Corrupt cache"):
                    subset.cached_source(spec, directory)
                target.unlink()
                with self.assertRaisesRegex(FileNotFoundError, "Offline cache miss"):
                    subset.cached_source(spec, directory, offline=True)

    def test_failed_download_digest_does_not_populate_cache(self):
        import io
        with tempfile.TemporaryDirectory() as directory:
            spec = {"url": "https://example.invalid/font", "sha256": "0" * 64}
            with patch("urllib.request.urlopen", return_value=io.BytesIO(b"wrong")):
                with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                    subset.cached_source(spec, directory)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_message_text_covers_every_icu_branch(self):
        self.assertEqual(subset.message_text("{month}月{day}日"), "月日")
        self.assertEqual(
            subset.message_text("{count, plural, one{1 条#} other{{count} 条}}"),
            "1 条 条")
        self.assertEqual(subset.message_text("{kind, select, a{甲} other{乙}}"), "甲乙")
        with self.assertRaises(ValueError):
            subset.message_text("{amount, number}")

    def test_gb2312_level_one_has_exactly_3755_characters(self):
        chars = subset.gb2312_level1()
        self.assertEqual(len(chars), 3755)
        self.assertIn(ord("家"), chars)

    def test_source_selection_and_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "app.arb").write_text(json.dumps({"handDate": "今天 {time}",
                "body": "正文", "@handDate": {"description": "忽略"}}))
            (root / "extra.txt").write_text("# 注释\n早饭\n", encoding="utf-8")
            (root / "presets.json").write_text(json.dumps({"items": [
                {"names": ["打车", "Taxi"]}]}))
            sources = [
                {"id": "hand", "file": "app.arb", "format": "json",
                 "keyPrefix": "hand", "targets": ["hand"]},
                {"id": "extra", "file": "extra.txt", "format": "text",
                 "targets": ["hand", "serif"]},
                {"id": "presets", "file": "presets.json", "format": "json",
                 "path": ["items", "*", "names", "*"], "targets": ["hand"]}]
            config = root / "sources.yaml"
            config.write_text(json.dumps({"sources": sources}))
            records = subset.read_sources(config, root)
            self.assertEqual(records[0][1], set(map(ord, "今天")))
            self.assertEqual(records[1][1], set(map(ord, "早饭")))
            self.assertEqual(records[2][1], set(map(ord, "打车Taxi")))
            self.assertEqual(subset.select_values(["hello"], ["0"]), ["hello"])


if __name__ == "__main__":
    unittest.main()
