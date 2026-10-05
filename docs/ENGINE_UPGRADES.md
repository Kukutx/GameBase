# Engine upgrade policy

GameBase follows stable Godot 4.x releases without permanently locking the repository to a patch version.

## Version model

- `.godot-version` is the Godot version used by CI and normal release builds.
- `licenses/GODOT_VERSION.txt` must match `.godot-version`; the adjacent Godot LICENSE/COPYRIGHT files are synchronized from that exact stable upstream tag.
- `project.godot -> application/config/features` is the minimum project feature line, not the CI patch version.
- Local development may use a newer stable Godot 4.x release before the shared CI baseline is advanced.
- Development, beta and release-candidate engine builds are not shared baselines unless explicitly requested.

This keeps builds reproducible while allowing regular engine upgrades. `.github/workflows/engine-compat.yml` also runs weekly against the newest stable Godot 4.x release and verifies both the test suite and all release exports without automatically changing the shared baseline. Compatibility exports use `--allow-engine-drift`; the export tool downloads a temporary official legal bundle for the actual tested stable engine and records that version in `BUILD_INFO.json`. These are compatibility artifacts, not release candidates.

## Upgrade procedure

1. Make sure the current branch is backed up in Git.
2. Check that GUT, Dialogue Manager and any other enabled addon support the target Godot release.
3. Install the new stable Godot release.
4. Update the CI baseline through the repository tool:

   ```text
   node tools/update_engine_baseline.js --version <major.minor.patch>
   ```

   The tool first downloads and validates the official `<version>-stable` `LICENSE.txt` and `COPYRIGHT.txt`. Only after both succeed does it update `.godot-version`, `licenses/GODOT_VERSION.txt`, `licenses/GODOT_LICENSE.txt`, and `licenses/GODOT_COPYRIGHT.txt` together.

5. Open/import the project once with the new engine.
6. Review any automatic `project.godot`, scene or resource-format changes.
7. Run:

   ```text
   node tools/validate.js
   node tools/export.js
   ```

8. Verify save migration/recovery tests and a real save/load cycle.
9. Commit the engine baseline, synchronized Godot legal bundle, addon compatibility updates and any engine-generated project-format changes together.

## Current baseline

The current shared validation baseline is Godot 4.7.2. The project feature marker is 4.7 because the test stack now uses GUT 9.7.1, which targets Godot 4.7.x. The project uses the Compatibility renderer so the same 2D codebase can target Windows, Linux and Web; Godot 4 Web exports require the Compatibility/WebGL 2 rendering path.

## Addon policy

Do not upgrade a dependency only because a newer major version exists. Prefer the newest compatible patch/minor release that does not force unrelated gameplay migrations. Major addon upgrades should be isolated, migration-tested and reversible.

Run `node tools/check_addon_updates.js` to compare vendored versions against upstream stable tags. `.github/workflows/addon-freshness.yml` runs the same check weekly and maintains a single upgrade-reminder issue when an update is available; it intentionally never mutates addon source automatically.

Dialogue Manager is on v4.1.0. The v3→v4 migration has been completed: GameBase uses `DialogueResource.cues`/`first_cue`, authored line/response translations use `msgctxt "dialogue"`, and the release PCK verifier preserves the v4 runtime `nodes/` dependencies while excluding editor/debugger tooling. GUT is on the 9.7 line to match Godot 4.7.
