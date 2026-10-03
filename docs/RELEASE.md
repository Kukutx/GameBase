# Release process

GameBase has reproducible Windows, Linux and Web exports, strict source validation, native package smoke tests and a real-browser Web smoke test.

## Prerequisites

- A compatible stable Godot 4.x build. The shared CI baseline is read from `.godot-version`.
- Matching Godot export templates.
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
5. main-scene boot smoke;
6. Windows, Linux and Web release exports;
7. Windows exported-build smoke on Windows hosts;
8. Web payload validation;
9. deterministic npm install and Chromium setup;
10. a Playwright browser launch of the Web export with console, page and network error checks.

Use `-SkipBrowserSmoke` only when browser tooling is intentionally unavailable. A release candidate should pass without that switch.

Expected outputs:

- `build/windows/GameBase.exe`
- `build/linux/GameBase.x86_64`
- `build/web/index.html`

Generated build, browser and diagnostic artifacts are intentionally ignored by Git.

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

Use semantic tags such as:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

`.github/workflows/release.yml` validates the source, exports and packages all three targets, performs Web browser smoke plus Windows/Linux packaged-build smoke, and only then publishes the GitHub Release.

Published assets include:

- `GameBase-windows-x86_64.zip`
- `GameBase-linux-x86_64.tar.gz`
- `GameBase-web.zip`
- `SHA256SUMS.txt`

The workflow can also be started manually to test packaging and smoke checks without publishing a GitHub Release.

## Secrets and signing

Desktop packages are currently unsigned. Signing/notarization credentials must never be committed to the repository. Add platform signing as protected repository/environment secrets when a storefront or distribution channel requires it.

## Licensed assets

Raw purchased assets under `game/art/licensed/` are intentionally excluded from Git and must not be redistributed. Release scenes must remain runnable with committed/runtime-safe assets or fallbacks.
