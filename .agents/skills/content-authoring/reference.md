# Finding the source of truth across systems

Read this only when a task crosses systems and the owner, the consumers or the verification entry point is not known. This file gives a method of discovery; it holds no content state, fixed version or project status.

## Locate from near to far

1. The source file of the change and its direct call chain.
2. The data resource class, the content pack, the save schema, the configuration and the version files.
3. The real consumers and the related tests.
4. The current fact pages the Profile names, the scripts under `tools/` and the CI workflows.
5. The state of an exported build, only when a difference between a local run and an export would affect the conclusion.
6. The current official documentation, only when an engine or addon capability, a version or a migration strategy is uncertain and would change the solution.

## Common owners

| Topic | Source of truth to look at first |
| --- | --- |
| Content of a type (item, crop, NPC, quest, mail, location, audio cue) | the resource class under `gamebase/core/` or `gamebase/modules/`, the resource under `games/<id>/game/data/`, the game's content pack (`games/farm1/game/data/content.tres` for Farm1), `ContentDB` and the module's `GameModule` that registers the kind |
| Runtime state of a system | the autoload service that owns it; a scene only presents it |
| What a save contains | `GameSaveManager` and the `to_save_data()` / `load_save_data()` pair of the owning service |
| Player-visible text | the string literal at its call site or in the scene or resource, the catalog of the owning layer (`gamebase/core/i18n/`, `gamebase/modules/<module>/i18n/` or the game's `game/i18n/`), `tools/check_localization.js` |
| Input actions | the `ControlAction` resources of the game's `GameDefinition.controls` and the core's `GameControls.CORE` in `gamebase/core/input/game_controls.gd` |
| Travel between locations | `WorldTravel`, the `WorldLocationData` resources and the `WorldSpawnPoint` nodes |
| Audio | `GameAudio`, the `AudioCueData` resources, `docs/AUDIO.md` |
| Engine and application versions | `.godot-version`, `config/version` in `games/<id>/project.godot`; whether to change them follows the officially supported facts |
| What an export contains | `games/<id>/export_presets.cfg`, `tools/verify_export_contents.js`, the export assertions in `tools/repository.test.js` and `games/farm1/test/unit/test_project_configuration.gd` |
| Verification commands | the scripts under `tools/`, `docs/RELEASE.md`, the workflows under `.github/workflows/` |
| Compatibility obligations | stable ids and exported resource fields that a derived game sets; saves have none (`.agents/rules/save.md`) |

## Stop signal

Once the owner, the affected consumers, the necessary synchronization and a verification entry point that can prove the result are confirmed, do not keep opening unrelated directories. Without evidence of a real consumer or of real data, a compatibility or version judgement does not create a migration layer from a historical template.
