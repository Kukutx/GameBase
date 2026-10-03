from __future__ import annotations

import argparse
import ast
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
PO = GAME / "i18n" / "ui.zh_CN.po"

CALL_PATTERNS = [
    re.compile(r'\btr\("((?:[^"\\]|\\.)*)"\)'),
    re.compile(r'GameEvents\.toast\("((?:[^"\\]|\\.)*)"'),
    re.compile(r'GameEvents\.toastf\("((?:[^"\\]|\\.)*)"'),
    re.compile(r'\bset_prompt\("((?:[^"\\]|\\.)*)"'),
]

SCENE_PATTERNS = [
    re.compile(r'^text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^dialog_text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^prompt_text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^title = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^ok_button_text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^cancel_button_text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^placeholder_text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^tooltip_text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^pending_text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
    re.compile(r'^completed_text = "((?:[^"\\]|\\.)*)"$', re.MULTILINE),
]

def decode_godot_string(raw: str) -> str:
    try:
        return ast.literal_eval(f'"{raw}"')
    except (SyntaxError, ValueError):
        return raw

def collect_source_keys() -> set[str]:
    keys: set[str] = set()
    for path in GAME.rglob("*.gd"):
        text = path.read_text(encoding="utf-8-sig")
        for pattern in CALL_PATTERNS:
            for raw in pattern.findall(text):
                value = decode_godot_string(raw)
                if value:
                    keys.add(value)
    for path in GAME.rglob("*.tscn"):
        text = path.read_text(encoding="utf-8-sig")
        for pattern in SCENE_PATTERNS:
            for raw in pattern.findall(text):
                value = decode_godot_string(raw)
                if value:
                    keys.add(value)
    return keys

def collect_po_entries() -> dict[str, str]:
    entries: dict[str, str] = {}
    msgid: str | None = None
    for raw_line in PO.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("msgid "):
            try:
                msgid = ast.literal_eval(line[6:])
            except (SyntaxError, ValueError):
                msgid = None
        elif line.startswith("msgstr ") and msgid is not None:
            try:
                entries[msgid] = ast.literal_eval(line[7:])
            except (SyntaxError, ValueError):
                entries[msgid] = ""
            msgid = None
    return entries

def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Simplified Chinese UI localization coverage.")
    parser.add_argument("--report-only", action="store_true", help="Print gaps without failing.")
    args = parser.parse_args()

    keys = collect_source_keys()
    entries = collect_po_entries()
    missing = sorted(key for key in keys if key not in entries or not entries[key])

    print(f"LOCALIZATION_SOURCE_KEYS={len(keys)}")
    print(f"LOCALIZATION_PO_ENTRIES={len(entries)}")
    print(f"LOCALIZATION_MISSING={len(missing)}")
    for key in missing:
        print(f"MISSING: {key}")

    if missing and not args.report_only:
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
