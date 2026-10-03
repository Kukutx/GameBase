from __future__ import annotations

import argparse
import hashlib
import io
import json
import pathlib
import re
import subprocess
import tarfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXPECTED_PACKAGES = {
    "windows": "GameBase-windows-x86_64.zip",
    "linux": "GameBase-linux-x86_64.tar.gz",
    "web": "GameBase-web.zip",
}
REQUIRED_PACKAGE_FILES = {
    "BUILD_INFO.json",
    "THIRD_PARTY_NOTICES.md",
    "licenses/GAMEBASE_LICENSE.txt",
    "licenses/GODOT_LICENSE.txt",
    "licenses/GODOT_COPYRIGHT.txt",
    "licenses/GODOT_VERSION.txt",
    "licenses/DIALOGUE_MANAGER_LICENSE.txt",
}


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8-sig").strip()


def plugin_version(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8-sig")
    match = re.search(r'^version="([^"]+)"$', text, re.MULTILINE)
    if not match:
        raise RuntimeError(f"Could not read plugin version from {path}")
    return match.group(1)


def git_commit() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
    )
    return result.stdout.strip()


def normalize_member(name: str) -> str:
    value = name.replace("\\", "/")
    while value.startswith("./"):
        value = value[2:]
    return value.rstrip("/")


def package_members(path: pathlib.Path) -> tuple[set[str], dict[str, bytes]]:
    payloads: dict[str, bytes] = {}
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path) as archive:
            names = {normalize_member(name) for name in archive.namelist()}
            for required in REQUIRED_PACKAGE_FILES:
                if required in names:
                    payloads[required] = archive.read(
                        next(name for name in archive.namelist() if normalize_member(name) == required)
                    )
            return names, payloads

    if path.name.endswith(".tar.gz"):
        with tarfile.open(path, "r:gz") as archive:
            members = {
                normalize_member(member.name): member
                for member in archive.getmembers()
                if member.isfile()
            }
            names = set(members)
            for required in REQUIRED_PACKAGE_FILES:
                member = members.get(required)
                if member is not None:
                    extracted = archive.extractfile(member)
                    if extracted is not None:
                        payloads[required] = extracted.read()
            return names, payloads

    raise RuntimeError(f"Unsupported release package format: {path.name}")


def validate_package(
    target: str,
    path: pathlib.Path,
    game_version: str,
    engine_version: str,
    commit: str,
    legal_version: str,
) -> dict[str, object]:
    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(f"Missing or empty {target} package: {path}")

    names, payloads = package_members(path)
    missing = sorted(REQUIRED_PACKAGE_FILES - names)
    if missing:
        raise RuntimeError(f"{path.name} is missing distribution files: {', '.join(missing)}")

    try:
        build_info = json.loads(payloads["BUILD_INFO.json"].decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"{path.name} has invalid BUILD_INFO.json: {exc}") from exc

    expected_target = {
        "windows": "Windows Desktop",
        "linux": "Linux",
        "web": "Web",
    }[target]
    checks = {
        "game_version": (str(build_info.get("game_version", "")), game_version),
        "git_commit": (str(build_info.get("git_commit", "")), commit),
        "target": (str(build_info.get("target", "")), expected_target),
        "legal_bundle_version": (
            str(build_info.get("legal_bundle_version", "")),
            legal_version,
        ),
    }
    for field, (actual, expected) in checks.items():
        if actual != expected:
            raise RuntimeError(
                f"{path.name} BUILD_INFO {field}={actual!r}, expected {expected!r}"
            )

    actual_engine = str(build_info.get("engine", ""))
    if not actual_engine.startswith(engine_version):
        raise RuntimeError(
            f"{path.name} BUILD_INFO engine={actual_engine!r}, expected {engine_version!r}"
        )
    if bool(build_info.get("dirty", True)):
        raise RuntimeError(f"{path.name} was built from a dirty source tree")

    packaged_legal_version = payloads["licenses/GODOT_VERSION.txt"].decode(
        "utf-8-sig"
    ).strip()
    if packaged_legal_version != legal_version:
        raise RuntimeError(
            f"{path.name} legal marker={packaged_legal_version!r}, expected {legal_version!r}"
        )

    return {
        "name": path.name,
        "target": target,
        "size_bytes": path.stat().st_size,
        "sha256": sha256(path),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate packaged release artifacts and generate release manifest/checksums."
    )
    parser.add_argument("--dist", type=pathlib.Path, default=ROOT / "dist")
    parser.add_argument("--game-version", default=read_text(ROOT / ".game-version"))
    parser.add_argument("--engine-version", default=read_text(ROOT / ".godot-version"))
    parser.add_argument("--git-commit", default=None)
    parser.add_argument("--tag", default="")
    args = parser.parse_args()

    dist = args.dist.resolve()
    commit = args.git_commit or git_commit()
    legal_version = read_text(ROOT / "licenses" / "GODOT_VERSION.txt")
    if legal_version != args.engine_version:
        raise RuntimeError(
            f"Godot legal bundle {legal_version} does not match engine {args.engine_version}"
        )

    artifacts: list[dict[str, object]] = []
    for target, filename in EXPECTED_PACKAGES.items():
        artifacts.append(
            validate_package(
                target,
                dist / filename,
                args.game_version,
                args.engine_version,
                commit,
                legal_version,
            )
        )

    manifest = {
        "schema": 1,
        "game_version": args.game_version,
        "tag": args.tag,
        "git_commit": commit,
        "godot_version": args.engine_version,
        "godot_legal_bundle_version": legal_version,
        "addons": {
            "dialogue_manager": plugin_version(
                ROOT / "addons" / "dialogue_manager" / "plugin.cfg"
            ),
            "gut": plugin_version(ROOT / "addons" / "gut" / "plugin.cfg"),
        },
        "artifacts": artifacts,
    }

    dist.mkdir(parents=True, exist_ok=True)
    manifest_path = dist / "RELEASE_MANIFEST.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    checksum_paths = [dist / item["name"] for item in artifacts] + [manifest_path]
    checksum_path = dist / "SHA256SUMS.txt"
    checksum_path.write_text(
        "".join(f"{sha256(path)}  {path.name}\n" for path in checksum_paths),
        encoding="utf-8",
        newline="\n",
    )

    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    print(f"RELEASE_MANIFEST_OK={manifest_path}")
    print(f"RELEASE_CHECKSUMS_OK={checksum_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
