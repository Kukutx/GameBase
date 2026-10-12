# Ember Depths

The second game built on GameBase, of another genre: a dungeon delve. From a camp the player goes down into the depths one floor at a time, clears each floor's enemies with the weapon in the hotbar, and climbs back up the rope with what they dropped, to sell it and buy a better blade. It uses the core and the `items`, `skills`, `combat` and `roguelite` modules, and keeps the foundation honest for a game that is not a life-sim.

## Run

From the repository root, link the foundation and the addons once, then open `games/dungeon1/project.godot` in Godot:

```text
node tools/link.js --game dungeon1
```

The main scene is the core title screen, `res://gamebase/core/ui/title_screen.tscn`. `node tools/validate.js --game dungeon1` runs this game's checks; its runtime check plays the loop and ends with `Delve smoke passed.`. The version lives in `config/version` of `project.godot`; a release is the tag `game/dungeon1/v<version>`.

## Layout

```text
game/data/         Data resources, listed in the content pack content.tres
game/depths/       The depths (the DepthRun autoload), a floor and the camp's way down
game/world/        The camp and the depths
game/player/       The player scene and controller
game/ui/           The HUD, which holds the core pause menu and the items module's shop
game/i18n/         The Simplified Chinese catalog of the game's own text
game/game_setup.gd The game's own module: why a run blocks saving, new items to the hotbar
test/unit/         Runs, floors, the way on, potions
test/runtime/      The delve smoke: camp, two depths, save and load, a defeat
```

## Gameplay

- A camp with a campfire (rest until tomorrow, which saves), a merchant who buys what the depths drop and sells potions and swords, and the way down
- Floors laid out from the run's random stream: the same run and depth always give the same floor, a new run new ones, and deeper floors more and harder enemies (`EnemyTier`: slimes from depth 1, skeletons from 3, ember wisps from 6)
- Stairs down and the rope back to camp open once every enemy of the floor is defeated
- Each trip down is a run of the roguelite module (`RunState`), from the way down until the rope back or a defeat; the game saves only between runs, at camp, and a defeat costs a quarter of the player's money
- Combat experience and three achievements, all triggers in `game/data/triggers/`; the deepest depth any save reached stays in the player's profile
- A clock that stands still: a day passes when the player rests or is defeated

Everything except the floors is the foundation's: the title, pause and settings menus, the hotbar, the melee attack, the enemies, the shop, the runs and the depth track, saving, the profile and the triggers.
