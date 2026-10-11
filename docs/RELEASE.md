# Release process

Every game under `games/` has reproducible Windows, Linux and Web exports, strict source validation, native package smoke tests and a real-browser Web smoke test. A release is one game at one version; the foundation and the addons it ships are the ones in the same commit.

## Prerequisites

- A valid SemVer in `config/version` of the game's `games/<id>/project.godot`.
- A compatible stable Godot 4.x build. Normal release exports must match the shared `.godot-version` baseline; `licenses/GODOT_VERSION.txt` and the official Godot legal bundle must match that same baseline.
- Matching Godot export templates.
- Node.js 24+ for the repository tooling and the Playwright Web-export smoke test.

Install the export templates for the current shared baseline with:

```text
node tools/install_export_templates.js
```

Every tool below takes `--game <id>`, else `GAMEBASE_GAME`, else the only registered game.

## One-command local release check

The preferred pre-release command is:

```text
node tools/release_readiness.js --game <id>
```

It performs:

1. repository, instruction and licensed-asset safety checks and `git diff --check` on project-owned files;
2. the repository checks of `tools/validate.js`: the agent rules and routing check (`tools/validate_rules.js --strict`), the layer dependency check (`tools/check_layers.js`), the tool tests (`node --test "tools/*.test.js"`), the deterministic packaging self-test, and a game freshly created from `gamebase/templates/new_game/` that must import, boot and run its runtime smoke;
3. the game checks of `tools/validate.js`: its links, its version, Simplified Chinese localization coverage, a clean Godot import from a regenerated `.godot/` cache, GUT unit tests (which also load every script and scene under its `res://game` and `res://gamebase`), every runtime script under its `test/runtime/` (for Farm1 the life-simulation smoke and a three-year long-horizon soak with 336 day transitions, 12 real disk save and load round trips and the Year 4 boundary) and a main-scene boot;
4. Windows, Linux and Web release exports;
5. resource-pack content verification: the main scene, the game definition, every autoload script, every translation and the runtime files of its addons must be present, while tests, GUT, `game.json`, `.gutconfig.json`, local licensed raw art, addon editor files and repository-only files must be absent;
6. distribution license and notices copied beside each platform payload;
7. the native exported-build smoke on the host platform and the Web payload validation;
8. deterministic npm install and Chromium setup, then a Playwright browser launch of the Web export with console, page and network error checks plus live resize checks at 1280×720, 1024×768, 2560×1080 and 800×600; the Godot canvas must remain visible and fully contained in each viewport;
9. deterministic archive packaging through `tools/package_release.js`, with sorted paths, commit-derived timestamps and canonical permissions and ownership metadata;
10. package identity verification and the release manifest through `tools/generate_release_manifest.js`.

Use `--skip-browser-smoke` only when browser tooling is intentionally unavailable. A release candidate should pass without that switch. `tools/release_readiness.js` also requires a clean Git working tree so packaged `BUILD_INFO.json` can point to one exact commit with `dirty=false`. `tools/validate.js` runs steps 2 and 3 and is the single local validation entry point; `--skip-soak` exists only for fast local iteration, and CI and release candidates run the soak. A Godot step fails on a non-zero exit code or on any `ERROR:` or `SCRIPT ERROR:` output line.

Expected outputs, named after `config/name` in the game's `project.godot` with anything but letters, digits, `_` and `-` removed (`<Name>` below; `Farm1` for Farm1):

- `build/<id>/windows/<Name>.exe`
- `build/<id>/linux/<Name>.x86_64`
- `build/<id>/web/index.html`

Generated build, browser and diagnostic artifacts are ignored by Git. Dialogue Manager release packs retain the runtime, compiler, settings, balloon and l10n resources required by `DialogueManager`, while its editor-only assets, components, views and plugin, import, export and inspector code are excluded and verified absent from the PCK. Every platform output also contains `BUILD_INFO.json`, `THIRD_PARTY_NOTICES.md` and the `licenses/` directory. `BUILD_INFO.json` records the game id, its version, the actual Godot version, the Git commit, the dirty state and the target platform. These distribution files are written after PCK verification and are not part of `res://`.

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`/`master`.

The workflow:

1. picks the games the run covers (`node tools/ci.js games`): every game, except on a pull request that changes nothing but some games' own `games/<id>/` directories, which covers only those games;
2. runs the repository checks once (`node tools/validate.js --no-games`);
3. validates each covered game from a clean import (`node tools/validate.js --no-repository --game <id> --clean-import`);
4. exports each covered game for Windows, Linux and Web;
5. checks the Web payload, launches it in Chromium and uploads the browser diagnostics;
6. launches the exported Windows build on a Windows runner and the Linux build on a Linux runner;
7. treats Godot `ERROR:` and `SCRIPT ERROR:` log lines as failures even when the engine process returns exit code 0.

A change should not be merged while any of these checks fail.

## Publishing a release

First bump and commit the game's version, then tag that exact version:

```text
node tools/update_game_version.js --game farm1 --version 0.2.0
git add games/farm1/project.godot
git commit -m "chore(farm1): release 0.2.0"
git tag game/farm1/v0.2.0
git push origin game/farm1/v0.2.0
```

The Release workflow rejects a tag unless it is exactly `game/<id>/v` plus the version committed in that game's `project.godot`.

`.github/workflows/release.yml` validates the source (the repository checks and that game), exports all three targets, packages them with the repository-owned deterministic packager, performs Web browser smoke plus Windows and Linux packaged-build smoke, validates package-internal identity, and only then publishes the GitHub Release `<Name> <version>` for that tag. The packager derives archive timestamps from `SOURCE_DATE_EPOCH` when set or from the Git commit timestamp, sorts every member path and normalizes modes and ownership, so repackaging the same payload is byte-for-byte stable.

Published assets, from `dist/<id>/`:

- `<Name>-windows-x86_64.zip`
- `<Name>-linux-x86_64.tar.gz`
- `<Name>-web.zip`
- `RELEASE_MANIFEST.json`
- `SHA256SUMS.txt`

Before publishing, `tools/generate_release_manifest.js` opens every ZIP and TAR package and verifies its internal `BUILD_INFO.json`, the game id and version, the Godot version, the exact Git commit, the clean-source flag, the target name, the Godot legal marker, third-party notices and required license files. Only then does it emit the external manifest and checksums. `RELEASE_MANIFEST.json` records the game id and version, the Godot and legal-bundle version, the versions of the addons the game links and the SHA-256 and size of all three platform packages.

The workflow can also be started manually, with a `game` input, to test packaging and smoke checks without publishing a GitHub Release. A manual `engine_version` override is treated as a compatibility build: exports explicitly use `--allow-engine-drift`, synchronize a temporary Godot legal bundle to that actual stable engine, and are not publishable release candidates. Tag-triggered releases use the committed `.godot-version` baseline.

## Secrets and signing

Desktop packages are currently unsigned. Signing and notarization credentials must never be committed to the repository. Add platform signing as protected repository or environment secrets when a storefront or distribution channel requires it.

## Licensed assets

Raw purchased assets under a game's `game/art/licensed/` are excluded from Git and must not be redistributed. Release scenes must remain runnable with committed runtime-safe assets or fallbacks. See `docs/LICENSED_ASSETS.md`.
