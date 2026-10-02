# Release process

GameBase has reproducible Windows, Linux and Web export presets plus GitHub Actions validation and release workflows.

## Local release check

Run the full validation suite:

```powershell
powershell -ExecutionPolicy Bypass -File tools/validate.ps1
```

Then verify all export templates are installed for the active Godot version and build all targets:

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1
```

Expected outputs:

- `build/windows/GameBase.exe`
- `build/linux/GameBase.x86_64`
- `build/web/index.html`

The `build/` directory is intentionally ignored by Git.

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`/`master`:

1. installs the Godot version from `.godot-version`;
2. imports/parses the project;
3. runs all GUT unit tests;
4. runs `test/runtime/world_services_smoke.gd`;
5. exports Windows, Linux and Web builds;
6. uploads short-lived CI build artifacts.

A change should not be merged while any of these checks fail.

## Publishing a release

Push an annotated or lightweight Git tag beginning with `v`, for example:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

`.github/workflows/release.yml` will validate the project again, package the three targets and create a GitHub Release using the tag.

The release workflow can also be started manually to test packaging without publishing a GitHub Release.

## Secrets and signing

The current pipeline produces unsigned desktop builds and a normal Web export. Platform signing credentials must never be committed to the repository. Add signing/notarization as repository or environment secrets when distribution requirements justify it.

## Licensed assets

Raw purchased assets under `game/art/licensed/` are intentionally excluded from Git and must not be redistributed. Release scenes must continue to work with committed/runtime-safe assets or fallbacks.
