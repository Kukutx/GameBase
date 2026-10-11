# gamebase

The reusable foundation every game built on GameBase shares. `game/` holds one game's own content, scenes and rules; everything here is meant to be reused by later games, games of other genres and in-game minigames.

```text
gamebase/core/                Genre-agnostic services: content, save, session, settings, input,
                              audio, world travel, time, interactions, dialogue, diagnostics
gamebase/modules/items/       Items, inventory, storage, shops, crafting, food buffs
gamebase/modules/npc_social/  NPC catalog, schedules, relationships, heart events, NPC memory
gamebase/modules/progression/ Quests, mail, skills, collections, contracts, town projects, upgrades
gamebase/modules/lifesim/     Farming, animals, fishing, forage, processing, building,
                              expansions, shipping, mining, calendar festivals
gamebase/modules/combat/      Hostile creatures and enemy data
```

Dependency direction: `game/` may use `gamebase/`; a module may use `core/`; `core/` must not depend on a module. This layout is the first step of that split: the files were moved without behaviour changes, and `core/` still reaches into modules in a few places (notably the late-night and collapse handling in `session/game_session.gd`); do not add new ones.

A game wires its modules into the core through registration, not through edits to `core/`: `game/game_setup.gd` registers each module's save sections, load-time repairs, save blockers and new-game steps, `game/content/game_content_database.gd` extends the generic `ContentRegistry` with the kinds of content its modules define, and `game/game_definition.tres` (named by the `gamebase/game_definition` project setting) gives the start location, home, starting clock and items.

Conditions and actions: content says when something is available and what it does with short text keys (`condition = "HAS_ITEM berry 3, !QUEST_COMPLETED first_harvest"`), parsed by `core/rules/game_query.gd` and evaluated by the `GameRules` autoload. The core registers time, weather, location, flag and money keys; each module registers its own (`modules/items/items_rules.gd`, `modules/progression/progression_rules.gd`, `modules/npc_social/npc_social_rules.gd`) when the game enables it in `game/game_setup.gd`. Every key content uses is checked at startup, so a typo fails validation. `WorldState` is the flag store: booleans through `get_bool`, counters through `get_int`/`add_int`.
