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

DATA_PATTERN = re.compile(r'^(?:display_name|title|description|subject|body|role) = "((?:[^"\\\\]|\\\\.)*)"$', re.MULTILINE)

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

def collect_dialogue_keys() -> set[str]:
    keys: set[str] = set()
    for path in GAME.rglob("*.dialogue"):
        for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
            line = raw_line.strip()
            if not line or line.startswith(("~", "=>", "#")):
                continue
            if line.startswith("- "):
                keys.add(line[2:].strip())
                continue
            match = re.match(r"^[^:]+:\s*(.+)$", line)
            if match:
                keys.add(match.group(1).strip())
    return keys


def collect_non_dialogue_keys() -> set[str]:
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
    for path in (GAME / "data").rglob("*.tres"):
        text = path.read_text(encoding="utf-8-sig")
        for raw in DATA_PATTERN.findall(text):
            value = decode_godot_string(raw)
            if value:
                keys.add(value)
    return keys


def collect_source_keys() -> set[str]:
    return collect_non_dialogue_keys() | collect_dialogue_keys()


def collect_po_entries() -> dict[tuple[str, str], str]:
    entries: dict[tuple[str, str], str] = {}
    for block in PO.read_text(encoding="utf-8").split("\n\n"):
        context = ""
        msgid: str | None = None
        msgstr: str | None = None
        for raw_line in block.splitlines():
            line = raw_line.strip()
            try:
                if line.startswith("msgctxt "):
                    context = ast.literal_eval(line[8:])
                elif line.startswith("msgid "):
                    msgid = ast.literal_eval(line[6:])
                elif line.startswith("msgstr "):
                    msgstr = ast.literal_eval(line[7:])
            except (SyntaxError, ValueError):
                continue
        if msgid is not None and msgstr is not None:
            entries[(context, msgid)] = msgstr
    return entries

def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Simplified Chinese UI localization coverage.")
    parser.add_argument("--report-only", action="store_true", help="Print gaps without failing.")
    args = parser.parse_args()

    dialogue_keys = collect_dialogue_keys()
    non_dialogue_keys = collect_non_dialogue_keys()
    keys = non_dialogue_keys | dialogue_keys
    entries = collect_po_entries()
    missing_generic = sorted(
        key for key in non_dialogue_keys if not entries.get(("", key), "")
    )
    missing_dialogue = sorted(
        key for key in dialogue_keys if not entries.get(("dialogue", key), "")
    )
    missing_count = len(missing_generic) + len(missing_dialogue)

    print(f"LOCALIZATION_SOURCE_KEYS={len(keys)}")
    print(f"LOCALIZATION_PO_ENTRIES={len(entries)}")
    print(f"LOCALIZATION_DIALOGUE_KEYS={len(dialogue_keys)}")
    print(f"LOCALIZATION_MISSING={missing_count}")
    print(f"LOCALIZATION_DIALOGUE_CONTEXT_MISSING={len(missing_dialogue)}")
    for key in missing_generic:
        print(f"MISSING: {key}")
    for key in missing_dialogue:
        print(f"MISSING_DIALOGUE_CONTEXT: {key}")

    if missing_count and not args.report_only:
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
