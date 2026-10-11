# Release recipe

Read only when the task is to prepare, check or publish a release, or to change the export and packaging chain. Preparing a candidate is not an authorization to tag, push or publish; each of those needs the current request to cover it. The facts and the list of what each command runs are in `docs/RELEASE.md`.

## Before a release candidate

```text
node tools/release_readiness.js --game <id>
```

It requires a clean Git working tree, then runs the repository checks, a clean import, the full validation including the three-year save/load soak, the three exports with pack verification, the native and Web payload smoke, the Chromium smoke of the Web export, the deterministic archives and the release manifest. `--skip-browser-smoke` is for a machine without browser tooling; a release candidate passes without it. `node tools/validate.js --skip-soak` is for fast local iteration only.

A Godot step fails on a non-zero exit code or on any `ERROR:` or `SCRIPT ERROR:` line, even when the engine exits with code 0.

## Engine and legal bundle

- A normal release export uses the engine in `.godot-version`; `licenses/GODOT_VERSION.txt` and the Godot legal bundle match it. `node tools/export.js` refuses another engine unless `--allow-engine-drift` is given, and an export made that way is a compatibility artifact, not a release candidate.
- Export templates for the baseline: `node tools/install_export_templates.js`.

## Version and tag

```text
node tools/update_game_version.js --game <id> --version <semver>
```

changes `config/version` in `games/<id>/project.godot`, the only place the game's version lives. The release tag is exactly `game/<id>/v<version>`, for example `game/farm1/v0.1.0`; the Release workflow rejects any other tag. Commit the version change before tagging, so that `BUILD_INFO.json` in every package names one exact commit with `dirty` false.

## What must be in and out of a package

- Each platform output contains `BUILD_INFO.json`, `THIRD_PARTY_NOTICES.md` and the `licenses/` directory beside the executable or Web payload; they are written after the pack has been verified and are not part of `res://`.
- A pack never contains `test/`, `addons/gut/`, `game/art/licensed/`, `tools/`, `docs/`, the agent instruction tree, CI metadata or repository-only files. A change to the exclusions in `games/<id>/export_presets.cfg` is matched in `tools/verify_export_contents.js`, `tools/repository.test.js` and `games/farm1/test/unit/test_project_configuration.gd`.
- Archives are built by `tools/package_release.js` with sorted paths, timestamps from the commit (or `SOURCE_DATE_EPOCH`) and fixed permissions, so packaging the same payload twice gives identical bytes. Do not replace it with a system `zip` or `tar` call.

## Publishing

The Release workflow publishes a GitHub Release of one game for a `game/<id>/v<version>` tag after validation, the three builds, the browser smoke, the packaged-build smoke on Windows and Linux and the manifest check. Publishing by hand is not part of this recipe.

## Reporting

Separate what was done, what was actually verified, the external or high-risk steps that were not executed, and real blockers. A prepared candidate is not "released"; a pushed tag is not a published release until the workflow result has been read.
