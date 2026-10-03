# Engine upgrade policy

GameBase follows stable Godot 4.x releases without permanently locking the repository to a patch version.

## Version model

- `.godot-version` is the Godot version used by CI and release builds.
- `project.godot -> application/config/features` is the minimum project feature line, not the CI patch version.
- Local development may use a newer stable Godot 4.x release before the shared CI baseline is advanced.
- Development, beta and release-candidate engine builds are not shared baselines unless explicitly requested.

This keeps builds reproducible while allowing regular engine upgrades. `.github/workflows/engine-compat.yml` also runs weekly against the newest stable Godot 4.x release and verifies both the test suite and all release exports without automatically changing the shared baseline.

## Upgrade procedure

1. Make sure the current branch is backed up in Git.
2. Check that GUT, Dialogue Manager and any other enabled addon support the target Godot release.
3. Install the new stable Godot release.
4. Update the CI baseline:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/update_engine_baseline.ps1 -Version <major.minor.patch>
   ```

5. Open/import the project once with the new engine.
6. Review any automatic `project.godot`, scene or resource-format changes.
7. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/validate.ps1
   powershell -ExecutionPolicy Bypass -File tools/export.ps1
   ```

8. Verify save migration/recovery tests and a real save/load cycle.
9. Commit the engine baseline, addon compatibility updates and any engine-generated project-format changes together.

## Current baseline

The current shared validation baseline is Godot 4.7.2. The project feature marker is 4.7 because the test stack now uses GUT 9.7.1, which targets Godot 4.7.x. The project uses the Compatibility renderer so the same 2D codebase can target Windows, Linux and Web; Godot 4 Web exports require the Compatibility/WebGL 2 rendering path.

## Addon policy

Do not upgrade a dependency only because a newer major version exists. Prefer the newest compatible patch/minor release that does not force unrelated gameplay migrations. Major addon upgrades should be isolated, migration-tested and reversible.

Dialogue Manager remains on the v3.10 line for now because v4 contains authored-dialogue format/API changes. GUT is on the 9.7 line to match Godot 4.7.
