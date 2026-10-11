# gamebase

The reusable foundation every game built on GameBase shares. `game/` holds one game's own content, scenes and rules; everything here is meant to be reused by later games, games of other genres and in-game minigames.

```text
gamebase/core/                Genre-agnostic services: content, save, session, rules, settings,
                              input, audio, world travel, time, interactions, diagnostics
gamebase/modules/items/       Items, inventory, storage, shops, crafting, food buffs
gamebase/modules/npc_social/  NPC actor, conversations, schedules, relationships, heart events, memory
gamebase/modules/progression/ Quests, mail, skills, collections, contracts, town projects, upgrades
gamebase/modules/lifesim/     Farming, animals, fishing, forage, processing, building,
                              expansions, shipping, mining, calendar festivals
gamebase/modules/combat/      Hostile creatures and enemy data
```

Dependency direction: `game/` may use `gamebase/`; a module may use `core/` and other modules; `core/` must not use a module, and nothing in `gamebase/` may use `game/` or name one of its content ids. `tools/check_layers.js` enforces this in validation. The `ContentDB` autoload is the one sanctioned crossing: its script lives in the game but extends the core `ContentRegistry`, and the check verifies that every method called on it exists. Violations that predate the check are listed with their reason in `tools/layer_baseline.json`; that list only shrinks.

A game wires its modules into the core through registration, not through edits to `core/`: `game/game_setup.gd` registers each module's save sections, load-time repairs, save blockers and new-game steps, `game/content/game_content_database.gd` extends the generic `ContentRegistry` with the kinds of content its modules define, and `game/game_definition.tres` (named by the `gamebase/game_definition` project setting) gives the start location, home, starting clock and items.

Conditions and actions: content says when something is available and what it does with short text keys (`condition = "HAS_ITEM berry 3, !QUEST_COMPLETED first_harvest"`), parsed by `core/rules/game_query.gd` and evaluated by the `GameRules` autoload. The core registers time, weather, location, flag and money keys; each module registers its own (`modules/items/items_rules.gd`, `modules/progression/progression_rules.gd`, `modules/npc_social/npc_social_rules.gd`) when the game enables it in `game/game_setup.gd`. Every key content uses is checked at startup, so a typo fails validation. `WorldState` is the flag store: booleans through `get_bool`, counters through `get_int`/`add_int`.
