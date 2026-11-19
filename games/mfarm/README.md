# MFarm

A small farm and a seaside town through the seasons, brought over from the Unity project MFarmDemo (Unity 2021.3, made along the Unity Learn China MFarm course) to Godot on the Tiamat core. Every asset of the old project came along: maps, characters, items, crops, trees, the interface, cursors, fonts, music and sounds. The game uses no gameplay module of Tiamat; its bags, land and townsfolk are its own (`game/`).

## Run

From the repository root, link the foundation once, then open `games/mfarm/project.godot` in Godot:

```text
node tools/link.js --game mfarm
```

The main scene is the core title screen. `node tools/validate.js --game mfarm` runs this game's checks; the runtime smoke ends with `MFarm smoke passed.`.

## Play

A new game starts on the beach at 07:00 on the first day of spring with an empty bag and 100 coins. The signposts lead to the field, where the tool box by the two signposts holds the tools and the house is home; the signposts in the field lead back to the beach and on to the market, where Koyo sells seeds.

| Control | Default |
| --- | --- |
| Move | WASD or arrow keys |
| Walk slowly | Shift |
| Use the item in hand on the cell under the cursor | Left mouse button |
| Pick an action bar slot | 1 to 0 |
| Bag | B or I |
| Talk, open a box | Space or E |
| Pause, close a bag | Escape |

Dig with the hoe, water with the can, plant seeds in dug soil in their season, pick ripe crops with the basket and sell them at Koyo's stall. Trees fall to the axe and leave stumps, rocks break to the pickaxe, weeds give hay to the sickle (four at a swing). Blueprints build a chair or a storage box on the cells that allow furniture. The clock runs as in the old game, one game minute every six seconds; thirty days make a month, three months a season. Night falls at 19:00, and the lamps light up.

## Layout

```text
game/unity/        Everything the importer converted from the old project (do not edit: tools/import_unity.js rewrites it)
game/data/         Items, bags and shops, blueprints, crops, maps, townsfolk, locations, sounds and controls, listed in content.tres
game/items/        Item, bag and blueprint data; the bags and money service (autoload Bags)
game/farm/         Crop and map data; the land service (autoload Farmland) and the grid that draws and works it
game/player/       The farmer (four animated layers, tools, a held item) and the cursor
game/npc/          Townsfolk: data, schedules, path finding, conversations
game/ui/           Action bar, bag, box and shop, trade panel, tooltip, clock and conversation box, in the old art
game/world/        The four locations, doorways, lights, fading scenery, boxes and items on the ground
game/i18n/         The Simplified Chinese catalog (English is the source)
test/unit/         GUT tests of the game's rules
test/runtime/      The end-to-end smoke: beach, field, digging and watering, the market, a purchase, save and load
```

The importer's settings for this game are `unity_import` in `game.json`; see [docs/UNITY_IMPORT.md](../../docs/UNITY_IMPORT.md).

## What the port fixed

The old project's own bug list (`Bug录.md`) and what turned up while porting:

- The sickle's weeds gave no hay; every weed now gives one or two.
- Buying with a full bag took the money and gave nothing; now the purchase is refused.
- A box lost its contents on loading a save, and the two boxes shared one index; each box now keeps its own contents in the save.
- Rocks and trees placed in a scene were destroyed when the map refreshed; they are put on the land once and kept with it.
- Crops read a stale season; they read the clock's season.
- Koyo could only be talked to from 03:00 of the second day, and townsfolk only moved at the exact minute of a schedule entry; they now stand where their schedule has them whenever a location opens.
- Townsfolk cut corners through obstacles, sped up on some cells, and kept walking after arriving; they walk at one speed around what blocks them.
- Escape did not close a box or a shop, and the pause menu had no way back to the game; both work now.
- After the sickle, switching tools left the body in the reaping animation; tool, arm and hair animations clashed and the hair covered the tool. Every part now changes with the item in hand, drawn body, hair, arm, tool, held item.
- The selection highlight stayed on a slot after dragging its item away.
- The cursor flickered over the interface while holding furniture.
- The clock dial stayed dark until 04:00 and then skipped a block; it fills one block every four hours.
- A conversation line without a speaker hid the name plates for good.
- One tree's trigger outline crossed itself; it is its convex hull now.
- Harvested crops sold for nothing; they now sell for more than their seeds cost.
- The field had no way to the market or the beach (the only doorway pointed at the interface scene); the signposts by the tool box lead there now.

## Credits

The art (the "Fantastic Farm RPG game assets") and the sounds came with the Unity Learn China MFarm course; the cursors are the Fantasy Cursor Pack; the interface font is GNU Unifont 14. See [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).
