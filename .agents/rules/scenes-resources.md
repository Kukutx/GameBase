---
path: "gamebase/**/*.tscn, gamebase/**/*.tres, games/*/game/**/*.tscn, games/*/game/**/*.tres"
---

# Scenes and resources (`gamebase/**/*.tscn`, `gamebase/**/*.tres`, `games/*/game/**/*.tscn`, `games/*/game/**/*.tres`)

The `.tscn` and `.tres` files under `gamebase/` and each game's `game/` were written as text rather than saved by the editor. Their headers carry `load_steps`, every `ext_resource` points at its file with `path=` and a readable id such as `id="1_player"`, none carries `uid=`, and nodes have no `unique_id`. New and edited files keep that shape. The engine behaviour described here was confirmed on Godot 4.7.2.

## P0

- **Reference other files by `path=` only**: do not write a `uid="uid://..."` value that was not copied from a file the engine produced. An unknown uid only prints a `WARNING` and the loader falls back to the path, and warnings do not fail validation, so the invented value stays in the repository.
- **Every resource id that is used has its entry**: an `ExtResource("id")` or `SubResource("id")` without a matching entry fails the whole load with `ERROR: ... Can't load cached ext-resource id`. After adding or renaming an entry, check every use of its id in the file.
- **Scene path fields hold `res://` paths**: `WorldLocationData.scene_path`, `PlaceableData.scene_path`, `ScenePortal.target_scene` and the licensed-art `asset_path` are `@export_file` strings. `WorldLocationData.find_for_scene()` and the save code compare `scene_path` with a scene's `scene_file_path` as plain strings, so a `uid://` value in these fields would never match.
- **Content exists for the game only after its pack lists it**: a data resource is listed in its game's content pack (`games/<id>/game/data/content.tres`), which takes two edits: an `ext_resource` line and an entry in `entries`; its kind is registered by the module that defines it. `ContentDB.rebuild()` runs at startup once the modules have installed (`GameModules`), indexes the packs, runs every entry's `find_problems()`, the location scene checks and the modules' content checks, and reports each problem with `push_error`, so a dangling reference fails every Godot step of `tools/validate.js`, not only the content tests.
- **A script and its `.gd.uid` change together**: every script has a `.gd.uid` file next to it, written by the engine during import. After adding a script, run the import step and commit the generated `.gd.uid`. When a script is renamed, moved or deleted, do the same to its `.gd.uid` in the same change.

## P1

- **A child node is declared after its parent**: `parent=` holds the path from the scene root (`parent="."`, `parent="Dim/Panel"`). Renaming a node means updating the `parent=` of everything below it, the `[connection]` entries, `NodePath` properties, and the `$Path` and `@onready` references in scripts.
- **An editor save rewrites the file**: saving a scene with 4.7 makes `load_steps` disappear and gives every node a `unique_id=`. Do not mix that rewrite into an unrelated change. When a scene has to be saved by the editor, commit the rewritten file on its own.
- **A node without an owner is not saved**: `PackedScene.pack()` saves a node created from code only when its `owner` is the scene root; a node without an owner is dropped from the saved file without a message.
- **Player-facing fields are read by the localization gate**: the fields `display_name`, `title`, `description`, `subject`, `body`, `role` and `activity` of data resources and the text properties of scenes need their translation; see `.agents/rules/localization.md`.

## P2

- `load_steps` is not read by 4.7.2: a wrong or missing value loads without any message. Existing files set it to the number of `ext_resource` and `sub_resource` entries plus one; keep it in step when that is cheap and do not spend time recomputing it otherwise.

## Verification

`node tools/validate.js --skip-soak` loads the manifest, runs `ContentDB.rebuild()` in every Godot step and boots the main scene. A scene that no test or smoke run instantiates has not been loaded by it (`.agents/rules/testing.md`). Carrying a content change through data, saves, text and tests: `.agents/skills/content-authoring/SKILL.md`.
