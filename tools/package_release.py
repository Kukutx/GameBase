from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import os
import pathlib
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]

TARGETS = {
    "Windows": {
        "source": ROOT / "build" / "windows",
        "output": ROOT / "dist" / "GameBase-windows-x86_64.zip",
        "format": "zip",
    },
    "Linux": {
        "source": ROOT / "build" / "linux",
        "output": ROOT / "dist" / "GameBase-linux-x86_64.tar.gz",
        "format": "tar.gz",
    },
    "Web": {
        "source": ROOT / "build" / "web",
        "output": ROOT / "dist" / "GameBase-web.zip",
        "format": "zip",
    },
}

ZIP_MIN_EPOCH = 315532800  # 1980-01-01 UTC


def git_commit_epoch() -> int:
    env_value = os.environ.get("SOURCE_DATE_EPOCH", "").strip()
    if env_value:
        try:
            return max(0, int(env_value))
        except ValueError as exc:
            raise RuntimeError("SOURCE_DATE_EPOCH must be an integer") from exc

    result = subprocess.run(
        ["git", "show", "-s", "--format=%ct", "HEAD"],
        cwd=ROOT,
        check=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
    )
    return max(0, int(result.stdout.strip()))


def source_files(source: pathlib.Path) -> list[pathlib.Path]:
    if not source.is_dir():
        raise RuntimeError(f"Missing release payload directory: {source}")
    files: list[pathlib.Path] = []
    for path in source.rglob("*"):
        if path.is_symlink():
            raise RuntimeError(f"Release payload must not contain symlinks: {path}")
        if path.is_file():
            files.append(path)
    if not files:
        raise RuntimeError(f"Release payload directory is empty: {source}")
    return sorted(files, key=lambda path: path.relative_to(source).as_posix())


def canonical_mode(target: str, relative: str) -> int:
    if target == "Linux" and relative == "GameBase.x86_64":
        return 0o755
    return 0o644


def build_zip(
    target: str,
    source: pathlib.Path,
    output: pathlib.Path,
    epoch: int,
) -> None:
    # ZIP timestamps have a 1980 lower bound and two-second resolution.
    normalized_epoch = max(epoch, ZIP_MIN_EPOCH)
    date_time = time.gmtime(normalized_epoch)[:6]

    with zipfile.ZipFile(
        output,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        strict_timestamps=True,
    ) as archive:
        for path in source_files(source):
            relative = path.relative_to(source).as_posix()
            info = zipfile.ZipInfo(relative, date_time=date_time)
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = ((stat.S_IFREG | canonical_mode(target, relative)) << 16)
            info.flag_bits = 0
            archive.writestr(
                info,
                path.read_bytes(),
                compress_type=zipfile.ZIP_DEFLATED,
                compresslevel=9,
            )


def build_tar_gz(
    target: str,
    source: pathlib.Path,
    output: pathlib.Path,
    epoch: int,
) -> None:
    with output.open("wb") as raw:
        with gzip.GzipFile(
            filename="",
            mode="wb",
            compresslevel=9,
            fileobj=raw,
            mtime=epoch,
        ) as compressed:
            with tarfile.open(
                fileobj=compressed,
                mode="w",
                format=tarfile.GNU_FORMAT,
            ) as archive:
                for path in source_files(source):
                    relative = path.relative_to(source).as_posix()
                    data = path.read_bytes()
                    info = tarfile.TarInfo(name=relative)
                    info.size = len(data)
                    info.mtime = epoch
                    info.uid = 0
                    info.gid = 0
                    info.uname = "root"
                    info.gname = "root"
                    info.mode = canonical_mode(target, relative)
                    archive.addfile(info, fileobj=io.BytesIO(data))


def package_target(
    target: str,
    source: pathlib.Path,
    output: pathlib.Path,
    epoch: int,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    archive_format = TARGETS[target]["format"]
    if archive_format == "zip":
        build_zip(target, source, output, epoch)
    elif archive_format == "tar.gz":
        build_tar_gz(target, source, output, epoch)
    else:
        raise RuntimeError(f"Unsupported archive format: {archive_format}")

    if not output.is_file() or output.stat().st_size <= 0:
        raise RuntimeError(f"Package was not created: {output}")
    print(f"PACKAGED {target}: {output} ({output.stat().st_size} bytes)")


def file_sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_self_test() -> int:
    epoch = 1_700_000_000
    fixtures = {
        "Windows": {
            "GameBase.exe": b"windows-binary\\x00" * 100,
            "GameBase.pck": b"pack-data" * 200,
            "licenses/GODOT_VERSION.txt": b"4.7.2\\n",
        },
        "Web": {
            "index.html": b"<html>GameBase</html>\\n",
            "index.wasm": b"wasm" * 300,
            "BUILD_INFO.json": b'{"game_version":"0.1.0"}\\n',
        },
        "Linux": {
            "GameBase.x86_64": b"linux-binary\\x00" * 100,
            "GameBase.pck": b"pack-data" * 200,
            "licenses/GODOT_VERSION.txt": b"4.7.2\\n",
        },
    }

    with tempfile.TemporaryDirectory(prefix="gamebase-package-selftest-") as temp_name:
        temp = pathlib.Path(temp_name)
        for target, files in fixtures.items():
            source = temp / target.lower()
            for relative, data in files.items():
                path = source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)

            suffix = ".tar.gz" if target == "Linux" else ".zip"
            first = temp / f"{target.lower()}-1{suffix}"
            second = temp / f"{target.lower()}-2{suffix}"
            package_target(target, source, first, epoch)
            package_target(target, source, second, epoch)

            first_hash = file_sha256(first)
            second_hash = file_sha256(second)
            if first_hash != second_hash:
                raise RuntimeError(
                    f"{target} packaging is not reproducible: {first_hash} != {second_hash}"
                )

            if target == "Linux":
                with tarfile.open(first, "r:gz") as archive:
                    names = archive.getnames()
                    if names != sorted(names):
                        raise RuntimeError("Linux archive entries are not sorted")
                    mode = archive.getmember("GameBase.x86_64").mode
                    if mode != 0o755:
                        raise RuntimeError(
                            f"Linux executable mode is {oct(mode)}, expected 0o755"
                        )
            else:
                with zipfile.ZipFile(first) as archive:
                    names = archive.namelist()
                    if names != sorted(names):
                        raise RuntimeError(f"{target} ZIP entries are not sorted")

            print(f"{target}_REPRO_OK={first_hash}")

    print("DETERMINISTIC_PACKAGING_OK")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create deterministic GameBase release archives."
    )
    parser.add_argument(
        "--target",
        choices=[*TARGETS.keys(), "All"],
        default="All",
    )
    parser.add_argument("--source", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--epoch", type=int)
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Build each archive format twice from fixtures and require identical SHA-256.",
    )
    args = parser.parse_args()

    if args.self_test:
        return run_self_test()

    if (args.source is None) != (args.output is None):
        parser.error("--source and --output must be provided together")
    if args.source is not None and args.target == "All":
        parser.error("--source/--output require one explicit --target")

    epoch = max(0, args.epoch if args.epoch is not None else git_commit_epoch())
    targets = list(TARGETS) if args.target == "All" else [args.target]

    for target in targets:
        source = (
            args.source.resolve()
            if args.source is not None
            else pathlib.Path(TARGETS[target]["source"])
        )
        output = (
            args.output.resolve()
            if args.output is not None
            else pathlib.Path(TARGETS[target]["output"])
        )
        package_target(target, source, output, epoch)

    print(f"SOURCE_DATE_EPOCH={epoch}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError, tarfile.TarError, zipfile.BadZipFile) as exc:
        print(f"Release packaging failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
