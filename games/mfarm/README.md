# MFarm

A small farm and a seaside town through the seasons, brought over from the Unity project MFarmDemo (Unity 2021.3, made along the Unity Learn China MFarm course) to Godot on the Tiamat core. Every asset of the old project came along: maps, characters, items, crops, trees, the interface, cursors, fonts, music and sounds. The game uses no gameplay module of Tiamat; its bags, land and townsfolk are its own (`game/`).

## Run

From the repository root, link the foundation once, then open `games/mfarm/project.godot` in Godot:

```text
node tools/link.js --game mfarm
```

The main scene is MFarm's title screen (`game/ui/title.tscn`), the old game's menu at its own size: a sheet of paper with three tabs down its right edge. The first sheet shows the title 麦田物语 in the old brush font and the version; 开始 brings the save slots, one card each, that continue the game saved there or start a new one (这个世界还没有开始, 梦还没开始; the little × deletes a slot after asking); 说明 the keys; 退出 quits. The gear in the corner opens the settings, and the questions show in wood menus of the old colours (`game/ui/mfarm_theme.tres`). It extends the core's `GameTitleBase`, which does what a title does with a slot. `node tools/validate.js --game mfarm` runs this game's checks; the runtime smoke ends with `MFarm smoke passed.`.

## Play

A new game starts on the beach at 07:00 on the first day of spring with an empty bag and 100 coins. It opens, as the old game did, with the comic of the storm that took the farmer's boat, over Calm 4 and timed as the old timeline was, then the farmer wakes, looks about and meets Mike (Escape skips it before the talk). The signposts lead to the field, where the tool box by the two signposts holds the tools and the house is home; the signposts in the field lead back to the beach and on to the market, where Koyo sells seeds.

| Control | Default |
| --- | --- |
| Move | WASD or arrow keys |
| Walk slowly | Shift |
| Use the item in hand on the cell under the cursor | Left mouse button |
| Pick an action bar slot | 1 to 0 |
| Bag | B or I |
| Talk, open a box | Space or E |
| Open the box next to you | Right mouse button |
| Run the clock fast, move on a day | Hold T, press G (the old game's time keys, which its menu told of) |
| Pause, close a bag | Escape |

Dig with the hoe, water with the can (the soil stays dark for the day; as in the old game, crops grow by the days, watered or not), plant seeds in dug soil in their season, pick ripe crops with the basket, held up for a moment as they go into the bag, and sell them at Koyo's stall. Trees fall to the axe and leave stumps, rocks break to the pickaxe, weeds rustle and sway as the farmer walks through them and give hay to the sickle (four at a swing). Blueprints build a chair or a storage box on the cells that allow furniture. The clock runs as in the old game, one game minute every six seconds; thirty days make a month, three months a season. Night falls at 19:00, and the lamps light up. Each place plays its ambient sound and its music over and over: arriving, the music before fades out and the place is heard alone for five to fifteen seconds before its own music fades in over eight, as the old game's did. Every tool sounds as it is used (the hoe, the can, the axe, the pickaxe, the basket, the sickle), and a crop with a sound of its own sounds that instead, as the old project's notes asked. Going through a door or along a road fades to black and back over a second and a half each way, as in the old game (at once with reduced motion), and the time panel writes the date as the old one did (2023年02月01日 in Chinese).

## Layout

```text
game/unity/        Everything the importer converted from the old project (do not edit: tools/import_unity.js rewrites it)
game/data/         Items, bags and shops, blueprints, crops, maps, townsfolk, locations, sounds and controls, listed in content.tres
game/items/        Item, bag and blueprint data; the bags and money service (autoload Bags)
game/farm/         Crop and map data; the land service (autoload Farmland) and the grid that draws and works it
game/player/       The farmer (four animated layers, tools, a held item) and the cursor
game/npc/          Townsfolk: data, schedules, path finding, conversations
game/ui/           Title, theme, opening comic, action bar, bag, box and shop, trade panel, tooltip, clock and conversation box, in the old art
game/world/        The four locations, doorways, lights, fading scenery, boxes and items on the ground
game/i18n/         The Simplified Chinese catalog (English is the source)
test/unit/         GUT tests of the game's rules and of the feel the old game had (the opening, swaying weeds, harvests held up, boxes, time keys)
test/runtime/      The end-to-end smoke: the opening, beach, field, digging and watering, the market, a purchase, save and load
```

The importer's settings for this game are `unity_import` in `game.json`; see [docs/UNITY_IMPORT.md](../../docs/UNITY_IMPORT.md). The old Unity project is retired now that the port is complete, so `game/unity/` is the copy of its assets to keep; the importer runs again only with a copy of the old project beside the repository (`unity_import.source`).

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
- Music and ambient sounds were imported to play once, so a place fell silent after its track; music and ambience now play over and over.
- The old light settings covered spring alone, so from summer on night never fell; every season now turns to the old night sky, as dark as the old one.
- The opening comic faded to three quarters and then vanished at once; it fades out fully as the farmer wakes.
- The menu's 退出 tab only showed the title sheet again (its ExitGame was never wired); it quits now, and the slot cards can delete a save, which the old menu could not.
- The axe, pickaxe and basket had no sound of their own, only the crops' (the old notes asked for a tool's sound that a crop's overrides); every tool has one now.

## Credits

The art (the "Fantastic Farm RPG game assets") and the sounds came with the Unity Learn China MFarm course; the cursors are the Fantasy Cursor Pack; the interface font is GNU Unifont 14. See [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).
