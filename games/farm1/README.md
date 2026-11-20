# Farm1

The first-generation game built on Tiamat: a farming life-sim across several connected towns. It uses the `items`, `skills`, `damage`, `combat`, `lifesim`, `npc_social`, `npc_ai` and `progression` modules and Dialogue Manager.

## Run

From the repository root, link the foundation and the addons once, then open `games/farm1/project.godot` in Godot:

```text
node tools/link.js --game farm1
```

The main scene is the core title screen, `res://tiamat/core/ui/title_screen.tscn`. `node tools/validate.js --game farm1` runs this game's checks; a successful runtime integration check ends with `LIFE_SIMULATION_SMOKE passed.`. The version lives in `config/version` of `project.godot`; a release is the tag `game/farm1/v<version>`.

## Layout

```text
game/data/         Data resources, listed in the content pack content.tres
game/dialogue/     Dialogue Manager scripts
game/world/        Playable locations and the shared world HUD
game/npc/          NPC scenes and presentation
game/player/       Player scene and controller
game/ui/           The game menu and the UI theme (title, pause and settings come from the core)
game/i18n/         The Simplified Chinese catalog of the game's own text (English is the source)
game/game_setup.gd The game's own module: what only Farm1 adds to the foundation
test/unit/         Focused GUT regression tests
test/runtime/      End-to-end life-simulation smoke and soak scripts
```

New content goes into the content pack `game/data/content.tres` and is read through its class's `find()` (`ItemData.find(&"berry")`) rather than hard-coded lookup tables.

## Gameplay

- Three connected settlements (Starter Town, Riverside Town, Harbor Town), the player home and the Old Mine
- Farming with seasonal crops, watering, harvests and sprinkler automation
- Fishing with location, season, time and weather pools and the reel minigame
- A 120-floor Old Mine with persistent depth, an elevator that stops at floor 1 and every fifth floor reached, the player picking the floor, ore tiers, escalating enemies (slimes recoloured per tier; on floors 21 to 39 about a third are Spitting Slimes, which keep their distance and spit goo that a step aside dodges and that leaves the player Poisoned, a little health each second for four seconds (`game/data/afflictions/`, the combat module's `AfflictionData`), which a Seaweed Tonic lifts, while a Cave Slime's touch leaves them Slimed, at 60% of their speed for two seconds (`AfflictionData.speed_scale`), a mixed tier: `EnemyTier.share`), guardians that bar the ladder on every 25th floor (a Slime King on 25 and 50, a Void Monarch from 75; weekly respawn, ore drops and an achievement each), elite slimes from floor 10 (`game/data/elites/`: Giant and Frenzied, one in twenty-five there and up to one in four from floor 62, with more drops and experience; `MineFloorTable.elite_odds`), magma vents from floor 40, one more every twentieth floor up to three, that glow before they flare and burn whatever stands on them, slimes too, Burning on a moment after (the combat module's `HazardSpread`: `MineFloorTable.hazards`), chests on about one floor in five from floor 2, each found once in a world, with ore of the floor's depth, Field Snacks and coins, and a Royal Hoard on every guarded floor, sealed until its guardian falls (the items module's `ChestSpread`: `MineFloorTable.chests`), melee combat with swords and a Slingshot from the general store that flings pebbles at the nearest slime ahead (the combat module's `RangedAttack`, on the tool control), and renewable resource nodes
- Farm animals with housing, feeding, happiness, naming, selling, premium products and 4→8→12 slot coop and barn expansions
- Inventory, hotbar, shops, crafting, cooking, buffs, processing and copper→iron→gold→iridium tool and weapon upgrades; the inventory tab shows the item chosen to bind with what it is, what it does (what a dish restores and gives, how hard a weapon hits beside the hardest hitting one carried) and every way to get more, and a recipe says where to get each ingredient the player lacks
- Placeable storage, machines and persistent building placement; a shipping bin settled overnight
- The Village General Store sells seeds by season and, once the Riverside Workshop Fund is complete, copper ore (a `ShopListing` with `PROJECT_COMPLETED riverside_workshop_fund`), ten a day (`ShopData.daily_limits`) and dearer than two ores smelted are worth, so the mine stays the way to plenty
- NPC schedules across towns, gifts (the game menu's social tab tells whether each NPC was talked to and given a gift today, and what the gifts given told of what they love, like and dislike; an item's details in the inventory tab say who was found to love or dislike it), 0→10-heart relationship dialogue and five heart-event tiers per core NPC
- A long mining quest chain, progression mail, daily contracts, seasonal festivals and chained town restoration projects
- Six skills with Lv5/Lv10 perks (Combat's raise max health, Farming's max energy, as Vegetable Stew's Hearty Worker does for four hours; at Combat 2 the kitchen roasts Fire-Roasted Tomatoes, two tomatoes over wood, whose Fiery Belly has one blow or shot in five set foes Burning for four hours, the game's `burn_chance` stat; and from the start a Seaweed Tonic, two seaweed and a berry, which lifts the Spitting Slimes' Poisoned when eaten, even at full health: its tag `antidote`, the affliction's `cure_tag`), collections and archive milestones
- Eleven achievements kept across every save, six of them counted over every save (crops, fish, gifts, mining, the mine's chests, and Monster Scholar's kinds of creature the bestiary has met) with their progress shown in the game menu and the achievements menu, two for the mine's guardians, and one hidden; the achievements menu's Records shows the counts with the deepest floor, the guardians felled and the chests opened
- The pause menu's Bestiary lists every kind of creature the farmer has defeated in the mines, across every save, with its health, its hits and its drop
- Three save slots with primary/backup/temp crash recovery, periodic and travel autosave
- Rebindable keyboard and gamepad controls, device-aware prompts, English and Simplified Chinese UI

## Licensed local art

Purchased source art is excluded from Git under `game/art/licensed/`. On the owner's workstation, restore the selected runtime assets with:

```text
node tools/sync_licensed_assets.js --game farm1
```

The packs are listed under `licensed_art` in `game.json`; see `docs/LICENSED_ASSETS.md` for the redistribution constraints. Every scene stays runnable without those files; the fallback visuals are part of the design.
