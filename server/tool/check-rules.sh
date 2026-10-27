#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
python3 - <<'PYTHON'
from pathlib import Path
import re
import sys

root = Path.cwd()
violations = []
for path in sorted((root / "crates/api").rglob("*")):
    if path.is_file():
        text = path.read_text()
        for match in re.finditer(r"\bSystemTx\b", text):
            violations.append((path, text.count("\n", 0, match.start()) + 1,
                               "SystemTx is forbidden in crates/api"))

# Inspect balanced calls so nested SQL expressions cannot hide a false flag.
def session_config_calls(text):
    for call in re.finditer(r"\b(?:pg_catalog\.)?set_config\s*\(", text, re.I):
        arguments = []
        argument_start = call.end()
        depth = 0
        quote = None
        cursor = call.end()
        while cursor < len(text):
            char = text[cursor]
            if quote:
                if char == quote:
                    if cursor + 1 < len(text) and text[cursor + 1] == quote:
                        cursor += 2
                        continue
                    quote = None
                elif char == "\\":
                    cursor += 2
                    continue
            elif char in {"'", '"'}:
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                if depth == 0:
                    arguments.append(text[argument_start:cursor])
                    break
                depth -= 1
            elif char == "," and depth == 0:
                arguments.append(text[argument_start:cursor])
                argument_start = cursor + 1
            cursor += 1
        if len(arguments) == 3:
            flag = re.sub(r"/\*.*?\*/", " ", arguments[2], flags=re.S).strip()
            if re.fullmatch(r"false(?:\s*::\s*(?:bool|boolean))?", flag, re.I):
                yield call

session_set = re.compile(r"\bSET\s+(?:SESSION\s+)?(?:jiabu\.|\"jiabu\.)", re.I)
for path in sorted(root.rglob("*")):
    if path.suffix not in {".rs", ".sql"} or "target" in path.relative_to(root).parts:
        continue
    text = path.read_text()
    matches = [(match, "Session-level jiabu settings are forbidden; use SET LOCAL")
               for match in session_set.finditer(text)]
    matches.extend((match, "set_config(..., false) is forbidden; use true")
                   for match in session_config_calls(text))
    for match, message in matches:
        violations.append((path, text.count("\n", 0, match.start()) + 1, message))
for path, line, message in violations:
    print(f"{path.relative_to(root)}:{line}: {message}", file=sys.stderr)
sys.exit(bool(violations))
PYTHON
