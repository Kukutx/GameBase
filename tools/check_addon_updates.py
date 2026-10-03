from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass

ROOT = pathlib.Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT / "artifacts" / "addon-updates.md"

SEMVER_RE = re.compile(
    r"^v?(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)$"
)

@dataclass(frozen=True, order=True)
class Version:
    major: int
    minor: int
    patch: int

    @classmethod
    def parse(cls, raw: str) -> "Version | None":
        match = SEMVER_RE.fullmatch(raw.strip())
        if not match:
            return None
        return cls(
            int(match.group("major")),
            int(match.group("minor")),
            int(match.group("patch")),
        )

    def __str__(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}"


ADDONS = [
    {
        "name": "Dialogue Manager",
        "plugin": ROOT / "addons" / "dialogue_manager" / "plugin.cfg",
        "repo": "https://github.com/nathanhoad/godot_dialogue_manager.git",
        "release_url": "https://github.com/nathanhoad/godot_dialogue_manager/releases",
    },
    {
        "name": "GUT",
        "plugin": ROOT / "addons" / "gut" / "plugin.cfg",
        "repo": "https://github.com/bitwes/Gut.git",
        "release_url": "https://github.com/bitwes/Gut/releases",
    },
]


def installed_version(plugin_path: pathlib.Path) -> Version:
    text = plugin_path.read_text(encoding="utf-8-sig")
    match = re.search(r'^version="([^"]+)"$', text, re.MULTILINE)
    if not match:
        raise RuntimeError(f"Could not read addon version from {plugin_path}")
    version = Version.parse(match.group(1))
    if version is None:
        raise RuntimeError(
            f"Addon version in {plugin_path} is not a stable semantic version: {match.group(1)}"
        )
    return version


def upstream_versions(repo: str) -> list[Version]:
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "--refs", repo],
        cwd=ROOT,
        check=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=90,
    )
    versions: set[Version] = set()
    for line in result.stdout.splitlines():
        if "\trefs/tags/" not in line:
            continue
        tag = line.rsplit("refs/tags/", 1)[-1]
        version = Version.parse(tag)
        if version is not None:
            versions.add(version)
    if not versions:
        raise RuntimeError(f"No stable semantic-version tags found for {repo}")
    return sorted(versions)


def build_report(rows: list[dict[str, object]]) -> str:
    updates = [row for row in rows if row["update_available"]]
    lines = [
        "# GameBase addon freshness",
        "",
        "This report is advisory. Addon upgrades remain explicit migrations and must pass the full validation/export suite.",
        "",
        "| Addon | Installed | Latest stable tag | Status |",
        "| --- | ---: | ---: | --- |",
    ]
    for row in rows:
        status = "Update available" if row["update_available"] else "Current"
        lines.append(
            f"| [{row['name']}]({row['release_url']}) | {row['installed']} | {row['latest']} | {status} |"
        )
    lines.extend(
        [
            "",
            f"Updates available: **{len(updates)}**",
            "",
            "For major addon updates, use a clean Git baseline and run clean import, GUT, runtime smoke, the three-year save/load soak, and all release exports before committing.",
        ]
    )
    return "\n".join(lines) + "\n"


def write_github_output(path: pathlib.Path, rows: list[dict[str, object]]) -> None:
    updates = [row for row in rows if row["update_available"]]
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"updates_available={'true' if updates else 'false'}\n")
        handle.write(f"update_count={len(updates)}\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare vendored Godot addon versions with latest stable upstream tags."
    )
    parser.add_argument(
        "--github-output",
        type=pathlib.Path,
        help="Optional GitHub Actions GITHUB_OUTPUT file to populate.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Also print machine-readable JSON after the human summary.",
    )
    parser.add_argument(
        "--fail-on-update",
        action="store_true",
        help="Exit 2 when a newer stable addon tag exists.",
    )
    args = parser.parse_args()

    rows: list[dict[str, object]] = []
    for addon in ADDONS:
        installed = installed_version(addon["plugin"])
        latest = upstream_versions(str(addon["repo"]))[-1]
        rows.append(
            {
                "name": addon["name"],
                "installed": str(installed),
                "latest": str(latest),
                "update_available": latest > installed,
                "repo": addon["repo"],
                "release_url": addon["release_url"],
            }
        )

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    report = build_report(rows)
    REPORT_PATH.write_text(report, encoding="utf-8", newline="\n")
    print(report, end="")
    print(f"ADDON_UPDATES_AVAILABLE={sum(bool(row['update_available']) for row in rows)}")

    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))

    output_path = args.github_output
    if output_path is None and os.environ.get("GITHUB_OUTPUT"):
        output_path = pathlib.Path(os.environ["GITHUB_OUTPUT"])
    if output_path is not None:
        write_github_output(output_path, rows)

    if args.fail_on_update and any(bool(row["update_available"]) for row in rows):
        return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        print(f"Addon freshness check failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
