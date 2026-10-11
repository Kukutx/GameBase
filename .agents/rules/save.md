---
path: "gamebase/core/save/**"
---

# Save data (`gamebase/core/save/**`)

`GameSaveManager` (`gamebase/core/save/`) writes each slot as JSON: a temp file is promoted to the primary and the previous primary is kept as a backup. `SAVE_VERSION` is the schema version and `SaveMigration` upgrades older saves one version at a time. The engine behaviour described here was confirmed on Godot 4.7.2.

## P0

- **Published saves keep loading**: that is a domain invariant of this base (`.agents/rules/project-domain.md`). A change to what a save contains or means goes through `SaveMigration`; a save from a newer build is never overwritten, rotated or repaired by an older one.
- **A new section changes the schema and is one change**: it needs all of the following together.
  1. Raise `GameSaveManager.SAVE_VERSION` and add the matching step to `SaveMigration.migrate`, which gives older saves a default for the section.
  2. Register a `SaveSection` for it: the foundation's own sections in `GameSaveManager._register_core_sections()`, a module's in the game's composition autoload (`game/game_setup.gd`). `since_version` is the new version, which makes saves of that version and later require the section. `order` is the restore order: `apply_snapshot()` restores global state before the saved scene is instantiated, and the order between services matters, so read the comments on the existing registrations before choosing it.
  3. Register a new-game step for it (`GameSession.register_new_game_step()`), otherwise a new game inherits the previous session's state.
  4. Derived state that depends on several sections is repaired by a load step (`SaveManager.register_load_step()`), which runs after every section is restored.
  5. Cover the migration in `test/unit/test_save_migration.gd`.
- **A new `WorldState` key needs a default on every read**: it does not change the schema, but saves written before it existed do not contain it.
- **Store stable ids only**: a node path, a scene file path or a list index is not a durable identity; scene renames are handled through Location and Spawn ids.
- **A write is checked**: `_write_dictionary()` reports success only when `FileAccess.store_string()` returned `true`. A save whose temp file could not be written stops before the primary or the backup is touched, and the failure reaches the player through `save_completed`.

## P1

- **Core never names a module or a content id**: `GameSaveManager` and `GameSession` only iterate what was registered with them and read the game's facts (start location, home, starting clock and items) from the `GameDefinition` named by the `gamebase/game_definition` project setting. A module service is wired in by `game/game_setup.gd`, never called from `gamebase/core`.
- **A section no registered service owns is kept**: data of a module this build does not enable is written back unchanged on the next save, and dropped only when a new game starts.
- **Where persistent state lives**: twelve services own a section of the save through `to_save_data()` and `load_save_data()`: `clock`, `weather`, `player_state` and `world` (core), and `inventory`, `relationships`, `npc_memory`, `quests`, `skills`, `buffs`, `shipping`, `fishing` (modules). Everything else that persists (animals, buildings, storage, mail, town projects, contracts, collections, farm plots, mine state and more) keeps its values in `WorldState` under its own keys, and `WorldState` is the `world` section.
- **A value that has been saved and loaded is not the value that was stored**, because of what JSON does to it:
  - Every number comes back as a `float`. `3.0 == 3` is true, but `match value:` with a `3` branch does not match `3.0`, and `{3: x}.has(3.0)` is false. Convert with `int()` (or the `_safe_int` helpers) before a `match`, a dictionary lookup, an array index or a comparison against an enum.
  - A `StringName` comes back as a `String`. Ids read from a save are converted with `StringName(String(value))` before they are used as ids.
  - Integer dictionary keys come back as string keys.
  - `Vector2`, `Color` and other engine types are written as their text form and come back as a `String`. Store their components, as the `player` section stores `x` and `y`.
- **Closing the window is a save point**: `AutoSaveService` asks for an autosave on `NOTIFICATION_WM_CLOSE_REQUEST`. With `auto_accept_quit` on, the handlers run to completion before the tree quits (confirmed on Windows), so that save stays synchronous; an `await` in it would never finish.
- **A save result is already translated**: `save_completed` and `load_completed` carry text in the current language, and `get_save_block_reason()` returns translated text or an empty string. A consumer shows the message as it is and tests a block with `is_empty()`, not against a sentence.
- **A test that writes a save uses its own files**: it points `SaveManager.save_path`, `temp_path` and `backup_path` at its own `user://` files, restores the three originals afterwards and deletes what it wrote (`test/unit/test_game_session_start.gd`).

## Verification

`test/runtime/long_horizon_soak.gd` performs real disk save and load round trips; a change to a section or to load-time reconciliation is not verified until the soak has run, so use `node tools/validate.js` without `--skip-soak`.
