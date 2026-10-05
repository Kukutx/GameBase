# Release process

GameBase has reproducible Windows, Linux and Web exports, strict source validation, native package smoke tests and a real-browser Web smoke test.

## Prerequisites

- A valid application SemVer in `.game-version`, matching `project.godot` `application/config/version`.
- A compatible stable Godot 4.x build. Normal release exports must match the shared `.godot-version` baseline; `licenses/GODOT_VERSION.txt` and the official Godot legal bundle must match that same baseline.
- Matching Godot export templates.
- Node.js 24+ for the repository tooling and the Playwright Web-export smoke test.

Install the export templates for the current shared baseline with:

```text
node tools/install_export_templates.js
```

## One-command local release check

The preferred pre-release command is:

```text
node tools/release_readiness.js
```

It performs:

1. repository/instruction/licensed-asset safety checks;
2. the agent rules and routing check (`tools/validate_rules.js --strict`) and the tool tests (`node --test "tools/*.test.js"`);
3. a clean Godot import from a regenerated `.godot/` cache;
4. Simplified Chinese localization coverage and the deterministic packaging self-test;
5. GUT unit tests, which also load every script and scene under `game/`;
6. runtime integration smoke;
7. a three-year long-horizon soak (336 day transitions, 12 real disk Save/Load round-trips, and the Year 4 boundary);
8. main-scene boot smoke;
9. Windows, Linux and Web release exports;
10. resource-pack content verification: runtime resources must be present while tests, GUT, local licensed raw art, tools/docs/CI metadata, the agent instruction tree and repository-only files must be absent;
11. distribution license/notices copied beside each platform payload;
12. deterministic archive packaging through `tools/package_release.js`, with sorted paths, commit-derived timestamps and canonical permissions/ownership metadata;
13. Windows exported-build smoke on Windows hosts;
14. Web payload validation;
15. deterministic npm install and Chromium setup;
16. a Playwright browser launch of the Web export with console, page and network error checks, plus live resize checks at 1280×720, 1024×768, 2560×1080 and 800×600; the Godot canvas must remain visible and fully contained in each viewport.

Use `--skip-browser-smoke` only when browser tooling is intentionally unavailable. A release candidate should pass without that switch. `tools/release_readiness.js` also requires a clean Git working tree so packaged `BUILD_INFO.json` can point to one exact commit with `dirty=false`. `tools/validate.js` runs steps 2 to 8 and is the single local validation entry point; `tools/validate.js --skip-soak` exists only for fast local iteration, and CI and release candidates run the soak by default. A Godot step fails on a non-zero exit code or on any `ERROR:` or `SCRIPT ERROR:` output line.

Expected outputs:

- `build/windows/GameBase.exe`
- `build/linux/GameBase.x86_64`
- `build/web/index.html`

Generated build, browser and diagnostic artifacts are intentionally ignored by Git. Dialogue Manager release packs retain the runtime/compiler/settings/balloon/l10n resources required by `DialogueManager`, while editor-only assets/components/views/plugin/import/export/inspector code are excluded and verified absent from the PCK. Every platform output also contains `BUILD_INFO.json`, `THIRD_PARTY_NOTICES.md`, and the `licenses/` directory. `BUILD_INFO.json` records the application version, actual Godot version, Git commit, dirty state, and target platform. These distribution metadata/legal files are written after PCK verification and are intentionally not part of `res://`.

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`/`master`.

The workflow:

1. resolves the Godot version from `.godot-version` or a manual override;
2. runs the repository-owned strict validation script;
3. exports Windows, Linux and Web with the repository-owned export script;
4. checks the Web payload and launches it in Chromium;
5. uploads browser diagnostics;
6. launches the exported Windows package on a Windows runner;
7. launches the exported Linux package on a Linux runner;
8. treats Godot `ERROR:` and `SCRIPT ERROR:` log lines as failures even when the engine process returns exit code 0.

A change should not be merged while any of these checks fail.

## Publishing a release

First bump and commit the application version, then tag that exact version:

```text
node tools/update_game_version.js --version 0.1.0
git add .game-version project.godot
git commit -m "chore: release 0.1.0"
git tag v0.1.0
git push origin v0.1.0
```

The Release workflow rejects a tag unless it is exactly `v` plus the committed `.game-version`.

`.github/workflows/release.yml` validates the source, exports all three targets, packages them with the repository-owned deterministic packager, performs Web browser smoke plus Windows/Linux packaged-build smoke, validates package-internal identity, and only then publishes the GitHub Release. The packager derives archive timestamps from `SOURCE_DATE_EPOCH` when set or from the Git commit timestamp, sorts every member path and normalizes modes/ownership so repackaging the same payload is byte-for-byte stable.

Published assets include:

- `GameBase-windows-x86_64.zip`
- `GameBase-linux-x86_64.tar.gz`
- `GameBase-web.zip`
- `RELEASE_MANIFEST.json`
- `SHA256SUMS.txt`

Before publishing, `tools/generate_release_manifest.js` opens every ZIP/TAR package and verifies its internal `BUILD_INFO.json`, GameBase/Godot versions, exact Git commit, clean-source flag, target name, Godot legal marker, third-party notices and required license files. Only then does it emit the external manifest and checksums. `RELEASE_MANIFEST.json` records the game version, Godot/legal-bundle version, vendored Dialogue Manager/GUT versions and the SHA-256/size of all three platform packages.

The workflow can also be started manually to test packaging and smoke checks without publishing a GitHub Release. A manual `engine_version` override is treated as a compatibility build: exports explicitly use `--allow-engine-drift`, synchronize a temporary Godot legal bundle to that actual stable engine, and are not publishable release candidates. Tag-triggered releases use the committed `.godot-version` baseline.

## Secrets and signing

Desktop packages are currently unsigned. Signing/notarization credentials must never be committed to the repository. Add platform signing as protected repository/environment secrets when a storefront or distribution channel requires it.

## Licensed assets

Raw purchased assets under `game/art/licensed/` are intentionally excluded from Git and must not be redistributed. Release scenes must remain runnable with committed/runtime-safe assets or fallbacks.
