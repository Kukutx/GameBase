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

Dependency direction: `game/` may use `gamebase/`; a module may use `core/`; `core/` must not depend on a module. This layout is the first step of that split: the files were moved without behaviour changes, and `core/` still reaches into modules in a few places (notably `content/content_database.gd` and the late-night and collapse handling in `session/game_session.gd`). Those references are removed as the content registry replaces them; until then, do not add new ones.

A game wires its modules into the core through registration, not through edits to `core/`: `game/game_setup.gd` registers each module's save sections, load-time repairs, save blockers and new-game steps, and `game/game_definition.tres` (named by the `gamebase/game_definition` project setting) gives the start location, home, starting clock and items.
