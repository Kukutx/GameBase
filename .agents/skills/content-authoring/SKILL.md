---
name: content-authoring
description: Add or change data-driven game content — items, crops, NPCs, quests, mail, locations, audio cues, dialogue or a new content type — so that the data, the content pack, ContentDB, saves, localization and tests stay in step. Use when one change has to be carried through two or more of those; not for a change inside a single script or for tuning one number in one resource.
---

# Content authoring across systems

One piece of content in this game is spread over several places that fail in different ways when one of them is forgotten. This skill is the map of those places. The file-format rules are in `.agents/rules/scenes-resources.md`, the text rules in `.agents/rules/localization.md`, the save rules in `.agents/rules/save.md`.

## Start from the source of truth

Work outward from the data resource and its class, then the content pack, then the consumers. Do not start from a menu or a scene and patch what it needs. When the owner, the consumers or the verification entry point of a change is not known, read `.agents/skills/content-authoring/reference.md`; it is not required reading every time.

## Adding content of an existing type

1. Create the resource under the matching directory of `games/<id>/game/data/` with its script class and a new, stable `id`. An id is never reused for something else; renaming an entry changes its id, and saves that used the old one load without it. Data a game or mod adds to an entry without changing its script goes in `custom_fields`.
2. List it in the game's content pack (`games/farm1/game/data/content.tres` for Farm1, the `ContentPack` that `game/game_definition.tres` names in `content`): one `ext_resource` line and one entry in `entries`.
3. Fill every cross-reference by id (an item named by a recipe, a quest that unlocks another, a location's `music_cue_id`). `ContentDB.rebuild()` runs every entry's `find_problems()` at startup and reports each problem with `push_error`, so a dangling reference fails every Godot step of validation.
4. Give every player-facing field (`display_name`, `short_name`, `title`, `description`, `subject`, `body`, `role`, and the `activity` of an NPC schedule entry) a Simplified Chinese entry.
5. Decide what an old save sees. Content that a save can reference by id (inventory, quests, mail, placed structures, collections) appears in saves made before it existed only through defaults and load-time reconciliation; content that is removed must degrade safely for saves that still name it.
6. Extend the focused test for that system and run `games/<id>/test/unit/test_content_database.gd`: `ContentDB.rebuild()` returns no errors and the new id resolves through its class's `find()`.

## Special cases

- **Location**: the scene, a `WorldLocationData` resource whose `scene_path` is a `res://` path, at least one `WorldSpawnPoint` in the scene for the default spawn id, and a music cue id. `ContentDB` validates that the scene and its spawn points exist. Travel to it goes through `WorldTravel` with Location and Spawn ids.
- **Audio cue**: an `AudioCueData` resource with a stable cue id; its stream may stay empty while production audio is pending. Gameplay code requests the cue id through `GameAudio` (`docs/AUDIO.md`).
- **Dialogue**: a `.dialogue` file under `games/<id>/game/dialogue/` listed in `locale/translations_pot_files` in `games/<id>/project.godot`; every authored line and response needs an entry with the `dialogue` context. Dialogue title ids that heart events or NPC progression refer to do not change.
- **Something that happens when an event fires** (experience for an action, a story beat, an achievement) is a `TriggerData` entry, not code in the game's `GameSetup`: its `event` names an autoload signal (`LifesimEvents.crop_harvested`), and its condition and actions read the event's arguments (`EVENT_ARG_AT_LEAST quantity 3`, `$combat_xp`, `repeat_per`).
- **Condition or action text**: a `condition` field (mail, heart events, farm expansions, NPC schedule entries, crafting and processing recipes, tool upgrades) takes a query such as `HAS_ITEM berry 3, !QUEST_COMPLETED first_harvest`; the keys and their arguments are documented on their registration in `gamebase/core/rules/game_rules.gd` and the modules' `*_rules.gd`. Every gate on another system's state is such a condition (`PROJECT_COMPLETED`, `MILESTONE_CLAIMED`, `EVENT_ACTIVE`, `HEARTS`, `DAY_AT_LEAST`), never a field of its own or a world flag a system writes for others to read; a field stays only where the owning system plans with it, such as a heart event's hearts (the order events play in) or a crop's seasons. A new key is registered there, never special-cased in a service; `games/farm1/test/unit/test_game_rules.gd` checks that all shipped content uses registered keys.
- **Stat change** (a food buff, a skill perk): `multipliers` and `bonuses` keyed by stats that a module or the game registers with `GameStats.register_stat()` when it installs (`gamebase/core/stats/game_stats.gd`); `GameStats.find_change_problems()` rejects any other stat. Code reads a stat through `GameStats` (`get_multiplier()`, `apply()`), never from the buff or the skill that changes it.
- **Skill**: a `SkillData` with the experience of each level (`level_xp`) and its perks as `SkillPerk` sub-resources at the levels that unlock them. What earns experience is the game's to decide: its `GameSetup` connects the module events it chooses to `Skills.add_xp()`.
- **Input action**: a `ControlAction` resource in the game's `GameDefinition.controls`, not the `[input]` section of `games/<id>/project.godot`; the core adds the controls its own systems read (`GameSettingsService.CORE_CONTROLS`).
- **Scene node with data of its own** (an id it saves, the location it belongs to, an id it names): it checks itself in `find_scene_problems(registry, location)` and names the world state it saves in `get_persistent_keys()`; `ContentDB` asks every node of every location scene (`gamebase/core/content/content_registry.gd`).

## Adding a new content type

1. A class that `extends ContentEntry` (`gamebase/core/content/content_entry.gd`, which provides `id` and `custom_fields`) in the module that owns it, with `class_name`, a `KIND` constant, typed fields and the static `find()` and `find_all()` lookups (written like a sibling class's).
2. Its checks in `find_problems(registry)`: its own fields and its references by id through `registry` (`registry.has_entry(ItemData.KIND, item_id)`), only to kinds of its module or of a module it requires. Each problem reads after the kind and id ("references unknown item 'x'"). A check that needs every entry of the kind at once (a graph without cycles) is a static function returning its problems.
3. The module's `GameModule.install()` registers the kind with `ContentDB.register_kind(MyData.KIND, MyData)` and such a check with `ContentDB.register_check()`. A game's own kind is registered by its `GameSetup` module (`game/game_setup.gd`).
4. A test in `games/<id>/test/unit/test_content_database.gd` for the index and for each new reference check, including one broken fixture that the check must reject.
5. When a save can refer to the new type, the save and new-game checklist in `.agents/rules/save.md`.

## Completion

The change is complete when every one of these is true for the content touched: the resource loads, the content pack lists it, `ContentDB.rebuild()` returns no errors, every visible string has its translation, an old save still loads, a new game starts, and `node tools/validate.js --skip-soak` passes — with the soak as well when saving, loading or day progression is affected. Anything not run is reported as not verified.
