# Engine upgrade recipe

Read only when the task is to move the shared Godot baseline or to judge the result of the weekly compatibility run. The policy is in `docs/ENGINE_UPGRADES.md`; the method for version work in general is `.agents/skills/toolchain/SKILL.md`. Moving the baseline is a dependency change and needs the current request to cover it.

## Steps

1. Start from a clean Git working tree on a branch, so the upgrade can be reviewed and reverted as one unit.
2. Confirm that GUT, Dialogue Manager and every other enabled addon support the target stable release.
3. Move the baseline:

   ```text
   node tools/update_engine_baseline.js --version <major.minor.patch>
   ```

   It downloads and validates the official `LICENSE.txt` and `COPYRIGHT.txt` of `<version>-stable` first and only then updates `.godot-version`, `licenses/GODOT_VERSION.txt`, `licenses/GODOT_LICENSE.txt` and `licenses/GODOT_COPYRIGHT.txt` together.
4. Install the matching export templates: `node tools/install_export_templates.js`.
5. Open or import the project once with the new engine and review every automatic change to `project.godot`, scenes and resources. Keep engine-generated format changes in their own commit.
6. Run the full validation and every export with the new engine:

   ```text
   node tools/validate.js --godot-bin <new engine> --clean-import
   node tools/export.js --godot-bin <new engine>
   ```

7. Check save migration and recovery: the save tests in `test/unit/` and one real save and load cycle with a save made before the upgrade.
8. Re-check the engine facts recorded in `.agents/rules/gdscript.md`, `.agents/rules/scenes-resources.md`, `.agents/rules/save.md` and `.agents/rules/testing.md`; they were confirmed on the previous baseline. Update the ones the new engine changes and keep only statements that were confirmed again.
9. Commit the baseline, the synchronized legal bundle, addon compatibility updates and engine-generated format changes together.

## The weekly compatibility run

`.github/workflows/engine-compat.yml` validates and exports against the newest stable Godot 4.x without moving the baseline. A failure there is information for the next upgrade, not a broken release. Its exports are compatibility artifacts built with `--allow-engine-drift`.

## Do not

- Use a development, beta or release-candidate engine as the shared baseline unless the user asks for it.
- Raise the feature marker in `project.godot` merely to match a patch release.
- Lower the baseline, delete a check or widen a version range to make a failing check pass.
