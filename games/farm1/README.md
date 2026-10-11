# Farm1

The first-generation game built on GameBase: a farming life-sim across several connected towns. It uses every foundation module (`items`, `npc_social`, `progression`, `lifesim`, `combat`) and Dialogue Manager.

## Run

From the repository root, link the foundation and the addons once, then open `games/farm1/project.godot` in Godot:

```text
node tools/link.js --game farm1
```

The main scene is `res://game/ui/title_screen.tscn`. `node tools/validate.js --game farm1` runs this game's checks; a successful runtime integration check ends with `LIFE_SIMULATION_SMOKE_OK`. The version lives in `config/version` of `project.godot`; a release is the tag `game/farm1/v<version>`.

## Layout

```text
game/data/         Data resources, listed in the content pack content.tres
game/dialogue/     Dialogue Manager scripts
game/world/        Playable locations and the shared world HUD
game/npc/          NPC scenes and presentation
game/player/       Player scene and controller
game/ui/           Title, pause, settings and game menus
game/i18n/         English and Simplified Chinese UI catalogs
game/game_setup.gd The game's own module: what only Farm1 adds to the foundation
test/unit/         Focused GUT regression tests
test/runtime/      End-to-end life-simulation smoke and soak scripts
```

New content goes into the content pack `game/data/content.tres` and is read through its class's `find()` (`ItemData.find(&"berry")`) rather than hard-coded lookup tables.

## Gameplay

- Three connected settlements (Starter Town, Riverside Town, Harbor Town), the player home and the Old Mine
- Farming with seasonal crops, watering, harvests and sprinkler automation
- Fishing with location, season, time and weather pools and the reel minigame
- A 120-floor Old Mine with persistent depth, elevator checkpoints every 5 floors, ore tiers, escalating enemies, melee combat and renewable resource nodes
- Farm animals with housing, feeding, happiness, naming, selling, premium products and 4→8→12 slot coop and barn expansions
- Inventory, hotbar, shops, crafting, cooking, buffs, processing and copper→iron→gold→iridium tool and weapon upgrades
- Placeable storage, machines and persistent building placement; a shipping bin settled overnight
- NPC schedules across towns, gifts, 0→10-heart relationship dialogue and five heart-event tiers per core NPC
- A long mining quest chain, progression mail, daily contracts, seasonal festivals and chained town restoration projects
- Six skills with Lv5/Lv10 perks, collections and archive milestones
- Three save slots with primary/backup/temp crash recovery, periodic and travel autosave
- Rebindable keyboard and gamepad controls, device-aware prompts, English and Simplified Chinese UI

## Licensed local art

Purchased source art is excluded from Git under `game/art/licensed/`. On the owner's workstation, restore the selected runtime assets with:

```text
node tools/sync_licensed_assets.js --game farm1
```

The packs are listed under `licensed_art` in `game.json`; see `docs/LICENSED_ASSETS.md` for the redistribution constraints. Every scene stays runnable without those files; the fallback visuals are part of the design.
