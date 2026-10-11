---
name: content-authoring
description: Add or change data-driven game content — items, crops, NPCs, quests, mail, locations, audio cues, dialogue or a new content type — so that the data, the manifest, ContentDB, saves, localization and tests stay in step. Use when one change has to be carried through two or more of those; not for a change inside a single script or for tuning one number in one resource.
---

# Content authoring across systems

One piece of content in this game is spread over several places that fail in different ways when one of them is forgotten. This skill is the map of those places. The file-format rules are in `.agents/rules/scenes-resources.md`, the text rules in `.agents/rules/localization.md`, the save rules in `.agents/rules/save.md`.

## Start from the source of truth

Work outward from the data resource and its class, then the manifest, then the consumers. Do not start from a menu or a scene and patch what it needs. When the owner, the consumers or the verification entry point of a change is not known, read `.agents/skills/content-authoring/reference.md`; it is not required reading every time.

## Adding content of an existing type

1. Create the resource under the matching directory of `game/data/` with its script class and a new, stable `id`. An id is never reused for something else; renaming an entry changes its id, and saves that used the old one load without it. Data a game or mod adds to an entry without changing its script goes in `custom_fields`.
2. Register it in `game/data/content_manifest.tres`: one `ext_resource` line and one entry in the matching array.
3. Fill every cross-reference by id (an item named by a recipe, a quest that unlocks another, a location's `music_cue_id`). `ContentDB.rebuild()` checks ids and references at startup and reports each problem with `push_error`, so a dangling reference fails every Godot step of validation.
4. Give every player-facing field (`display_name`, `title`, `description`, `subject`, `body`, `role`, and the `activity` of an NPC schedule entry) a Simplified Chinese entry.
5. Decide what an old save sees. Content that a save can reference by id (inventory, quests, mail, placed structures, collections) appears in saves made before it existed only through defaults and load-time reconciliation; content that is removed must degrade safely for saves that still name it.
6. Extend the focused test for that system and run `test/unit/test_content_database.gd`: `ContentDB.rebuild()` returns no errors and the new id resolves.

## Special cases

- **Location**: the scene, a `WorldLocationData` resource whose `scene_path` is a `res://` path, at least one `WorldSpawnPoint` in the scene for the default spawn id, and a music cue id. `ContentDB` validates that the scene and its spawn points exist. Travel to it goes through `WorldTravel` with Location and Spawn ids.
- **Audio cue**: an `AudioCueData` resource with a stable cue id; its stream may stay empty while production audio is pending. Gameplay code requests the cue id through `GameAudio` (`docs/AUDIO.md`).
- **Dialogue**: a `.dialogue` file under `game/dialogue/` listed in `locale/translations_pot_files` in `project.godot`; every authored line and response needs an entry with the `dialogue` context. Dialogue title ids that heart events or NPC progression refer to do not change.
- **Condition or action text**: a `condition` field (mail, heart events, NPC schedule entries) takes a query such as `HAS_ITEM berry 3, !QUEST_COMPLETED first_harvest`; the keys and their arguments are documented on their registration in `gamebase/core/rules/game_rules.gd` and the modules' `*_rules.gd`. A new key is registered there, never special-cased in a service; `test/unit/test_game_rules.gd` checks that all shipped content uses registered keys.
- **Rebindable action**: the constants in `gamebase/core/settings/game_settings.gd`, not the `[input]` section of `project.godot` (`.agents/rules/gdscript.md`).

## Adding a new content type

1. A class that `extends ContentEntry` (`gamebase/core/content/content_entry.gd`, which provides `id` and `custom_fields`) with `class_name` and typed fields, in the module that owns it.
2. An exported typed array in `game/content/content_manifest.gd`.
3. In `game/content/game_content_database.gd`: a `KIND_*` constant, a `register_entries()` call in `_index_content()`, the typed `get_*` (through `get_entry()`, so former ids resolve) and `get_all_*` accessors, and reference checks in `_validate_references()`. Write a check as a function that appends its messages to the `errors` array so a test can assert on them. `gamebase/core/content/content_registry.gd` stays generic: it owns only locations and audio cues.
4. A test in `test/unit/test_content_database.gd` for the index and for each new reference check, including one broken fixture that the check must reject.
5. When a save can refer to the new type, the save and new-game checklist in `.agents/rules/save.md`.

## Completion

The change is complete when every one of these is true for the content touched: the resource loads, the manifest lists it, `ContentDB.rebuild()` returns no errors, every visible string has its translation, an old save still loads, a new game starts, and `node tools/validate.js --skip-soak` passes — with the soak as well when saving, loading or day progression is affected. Anything not run is reported as not verified.
