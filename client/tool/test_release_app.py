#!/usr/bin/env python3

import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name("release_app.py")


class ReleaseAppTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.temp.cleanup()

    def run_case(self, version="1.2.0+12", tag="app-v1.2.0", metadata=None):
        root = pathlib.Path(self.temp.name)
        (root / "pubspec.yaml").write_text(f"name: fake\nversion: {version}\n")
        (root / "metadata.json").write_text(json.dumps(metadata or {
            "min_server_api": 1,
            "security_force": False,
            "notes": {"zh-Hans": "虚构说明", "en": "Fictional notes"},
        }))
        (root / "app.apk").write_bytes(b"fictional apk")
        result = subprocess.run([
            sys.executable, "-I", str(SCRIPT),
            "--pubspec", str(root / "pubspec.yaml"),
            "--metadata", str(root / "metadata.json"),
            "--tag", tag,
            "--apk", str(root / "app.apk"),
            "--output-dir", str(root / "out"),
        ], capture_output=True, text=True, check=False)
        return result, root / "out"

    def test_stable_output_and_digest(self):
        result, output = self.run_case()
        self.assertEqual(result.returncode, 0, result.stderr)
        release = json.loads((output / "release.json").read_text())
        self.assertEqual(release["channel"], "stable")
        self.assertEqual(release["build"], 12)
        checksum = (output / "jiabu-1.2.0-12-stable.apk.sha256").read_text()
        self.assertIn("jiabu-1.2.0-12-stable.apk", checksum)

    def test_beta_output(self):
        result, output = self.run_case("1.2.0-beta.3+13", "app-v1.2.0-beta.3")
        self.assertEqual(result.returncode, 0, result.stderr)
        release = json.loads((output / "release.json").read_text())
        self.assertEqual(release["channel"], "beta")

    def test_channel_only_validates_tag_and_prints_beta(self):
        root = pathlib.Path(self.temp.name)
        (root / "pubspec.yaml").write_text("name: fake\nversion: 1.2.0-beta.4+14\n")
        result = subprocess.run([
            sys.executable, "-I", str(SCRIPT),
            "--pubspec", str(root / "pubspec.yaml"),
            "--tag", "app-v1.2.0-beta.4",
            "--print-channel",
        ], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "beta")
        mismatch = subprocess.run([
            sys.executable, "-I", str(SCRIPT),
            "--pubspec", str(root / "pubspec.yaml"),
            "--tag", "app-v1.2.0-beta.5",
            "--print-channel",
        ], capture_output=True, text=True, check=False)
        self.assertNotEqual(mismatch.returncode, 0)

    def test_tag_mismatch_fails(self):
        result, _ = self.run_case(tag="app-v1.2.1")
        self.assertNotEqual(result.returncode, 0)

    def test_missing_either_note_fails(self):
        for notes in ({"en": "English"}, {"zh-Hans": "中文"}):
            with self.subTest(notes=notes):
                result, _ = self.run_case(metadata={
                    "min_server_api": 1,
                    "security_force": False,
                    "notes": notes,
                })
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
