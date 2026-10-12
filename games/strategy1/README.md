# Iron Banners

The third game built on GameBase, of a third genre: strategy. From a camp the player plans battles on a war table and fights them on a grid in active time, commanding their banner's units against raiders. It uses the core and the `combat`, `items` and `tactics` modules, and keeps the foundation honest for a game whose fights are turns on a grid rather than swings in the world.

## Run

From the repository root, link the foundation and the addons once, then open `games/strategy1/project.godot` in Godot:

```text
node tools/link.js --game strategy1
```

The main scene is the core title screen, `res://gamebase/core/ui/title_screen.tscn`. `node tools/validate.js --game strategy1` runs this game's checks; its runtime check opens the battle at the ford and walks the camp, and ends with `Camp smoke passed.`. The version lives in `config/version` of `project.godot`; a release is the tag `game/strategy1/v<version>`.

## Layout

```text
game/data/         Data resources, listed in the content pack content.tres
game/data/tactics/ The battle at the ford: its map, the units of both sides, their actions and the minigame
game/world/        The camp, with the war table, and the lookout
game/player/       The player scene and controller
game/ui/           The HUD, which holds the core pause menu
game/i18n/         The Simplified Chinese catalog of the game's own text
game/game_setup.gd The game's own module
test/unit/         The ford's map and a battle fought to its end
test/runtime/      The camp smoke: the war table, the lookout, sleep, save and load
```

## Gameplay

- The war table in the camp (a core `MiniGameStation`) opens the battle at the Border Ford, the tactics module's `GridBattleGame`
- A river that only the ford crosses, rocks, and four of the player's units (two swordsmen, an archer, a cleric who mends) against four raiders (two raiders, a brute, a slinger whose firepots burn an area)
- Every unit's gauge fills at its speed; on its turn a unit moves and acts once each, and one that skips either comes back sooner
- Time stands still while the player picks a command; cancel twice gives the battle up

Everything but the map and its units is the foundation's: the title, pause and settings menus, the war table, the battle, its board and its foes' play, saving and the profile.
