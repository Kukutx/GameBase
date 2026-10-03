# Release process

GameBase has reproducible Windows, Linux and Web exports, strict source validation, native package smoke tests and a real-browser Web smoke test.

## Prerequisites

- A valid application SemVer in `.game-version`, matching `project.godot` `application/config/version`.
- A compatible stable Godot 4.x build. Normal release exports must match the shared `.godot-version` baseline; `licenses/GODOT_VERSION.txt` and the official Godot legal bundle must match that same baseline.
- Matching Godot export templates.
- Python 3.12+ for localization coverage validation.
- Node.js 24+ for the Playwright Web-export smoke test.

Install the export templates for the current shared baseline with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/install_export_templates.ps1
```

## One-command local release check

The preferred pre-release command is:

```powershell
powershell -ExecutionPolicy Bypass -File tools/release_readiness.ps1
```

It performs:

1. repository/instruction/licensed-asset safety checks;
2. a clean Godot import from a regenerated `.godot/` cache;
3. GUT unit tests;
4. runtime integration smoke;
5. a three-year long-horizon soak (336 day transitions, 12 real disk Save/Load round-trips, and the Year 4 boundary);
6. main-scene boot smoke;
7. Windows, Linux and Web release exports;
8. resource-pack content verification: runtime resources must be present while tests, GUT, local licensed raw art, tools/docs/CI metadata and repository-only files must be absent;
9. distribution license/notices copied beside each platform payload;
10. Windows exported-build smoke on Windows hosts;
11. Web payload validation;
12. deterministic npm install and Chromium setup;
13. a Playwright browser launch of the Web export with console, page and network error checks, plus live resize checks at 1280×720, 1024×768, 2560×1080 and 800×600; the Godot canvas must remain visible and fully contained in each viewport.

Use `-SkipBrowserSmoke` only when browser tooling is intentionally unavailable. A release candidate should pass without that switch. `tools/validate.ps1 -SkipSoak` exists only for fast local iteration; CI and release candidates run the soak by default.

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

```powershell
powershell -ExecutionPolicy Bypass -File tools/update_game_version.ps1 -Version 0.1.0
git add .game-version project.godot
git commit -m "chore: release 0.1.0"
git tag v0.1.0
git push origin v0.1.0
```

The Release workflow rejects a tag unless it is exactly `v` plus the committed `.game-version`.

`.github/workflows/release.yml` validates the source, exports and packages all three targets, performs Web browser smoke plus Windows/Linux packaged-build smoke, and only then publishes the GitHub Release.

Published assets include:

- `GameBase-windows-x86_64.zip`
- `GameBase-linux-x86_64.tar.gz`
- `GameBase-web.zip`
- `SHA256SUMS.txt`

The workflow can also be started manually to test packaging and smoke checks without publishing a GitHub Release. A manual `engine_version` override is treated as a compatibility build: exports explicitly use `-AllowEngineDrift`, synchronize a temporary Godot legal bundle to that actual stable engine, and are not publishable release candidates. Tag-triggered releases use the committed `.godot-version` baseline.

## Secrets and signing

Desktop packages are currently unsigned. Signing/notarization credentials must never be committed to the repository. Add platform signing as protected repository/environment secrets when a storefront or distribution channel requires it.

## Licensed assets

Raw purchased assets under `game/art/licensed/` are intentionally excluded from Git and must not be redistributed. Release scenes must remain runnable with committed/runtime-safe assets or fallbacks.
