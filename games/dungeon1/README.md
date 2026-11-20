# Ember Depths

The second game built on Tiamat, of another genre: a dungeon delve. From a camp the player goes down into the depths one floor at a time, clears each floor's enemies with the weapon in the hotbar, and climbs back up the rope with what they dropped, to sell it and buy a better blade. It uses the core and the `items`, `skills`, `damage`, `combat` and `roguelite` modules, and keeps the foundation honest for a game that is not a life-sim.

## Run

From the repository root, link the foundation and the addons once, then open `games/dungeon1/project.godot` in Godot:

```text
node tools/link.js --game dungeon1
```

The main scene is the core title screen, `res://tiamat/core/ui/title_screen.tscn`. `node tools/validate.js --game dungeon1` runs this game's checks; its runtime check plays the loop and ends with `Delve smoke passed.`. The version lives in `config/version` of `project.godot`; a release is the tag `game/dungeon1/v<version>`.

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
test/runtime/      The delve smoke: camp, two depths, save and load, a defeat, a shortcut
```

## Gameplay

- A camp with a campfire (rest until tomorrow, which saves), a merchant who buys what the depths drop and sells potions, antidotes, swords (each telling how hard it hits beside the hardest hitting one the player carries, `WeaponUse.rival_of()`), among them the Ember Blade whose hits set what they strike Burning (its tag `burns`, the affliction's `weapon_tag`), and a Bone Bow (shot on the attack control, at the nearest foe ahead), and the way down
- The Ember Forge at camp turns what the runs bring back into lasting upgrades (the items module's `StatUpgradeData`, `StatUpgradeStand`): a tempered blade, a hardened hide and hearthblood (20 more health a level) in three levels, fleet boots in two, and, once the player reached depth 10, an ember brand that costs two ember cores; all of them at their last level is Fully Forged
- Floors laid out from the run's random stream: the same run and depth always give the same floor, a new run new ones, and deeper floors more and harder enemies (`EnemyTier`: slimes from depth 1, skeletons from 3, bone archers from 4, which keep their distance and loose bone darts, ember wisps from 6, which keep their distance and glow before they shoot embers that a step aside dodges and that set the player Burning, a little health each second for two seconds (`game/data/afflictions/burning.tres`, the combat module's `AfflictionData`), while a Cave Slime's touch leaves them Slimed, at 60% of their speed for two seconds (`slimed.tres`, `AfflictionData.speed_scale`), and venom slimes from 8, tougher, whose touch leaves them Poisoned, a health a second for eight seconds (`poisoned.tres`), which an Antidote lifts (`antidote.tres`, the camp merchant's and the Ember Peddler's, whose tag is the affliction's `cure_tag`; the potion key drinks one first while poisoned), while wisps and Wardens never burn); every fifth depth an Ember Warden, a guardian tier that glows as it winds up each strike, holds the floor with half the creatures, standing furthest from the way in, and the way on opens once it falls (two ember cores, and Warden Felled the first time); from depth 3 a creature may come as an elite (`game/data/elites/`: Hulking, larger and tougher, Swift, fast, and Searing, hitting hard and setting the player Burning), one in twenty at depth 3 and up to about one in three from depth 13, worth more experience and one more drop; from depth 3 ember vents (the combat module's `Hazard`, spread by the depths scene's `HazardSpread`) flare on the floor in turn, one more every second depth up to four, clear of the ways in and on: each glows before it flares and burns whatever stands on it, the player or a creature lured across it, which keeps Burning a moment after; about one floor in three holds a chest (the items module's `LootChest`, spread by `game/depths/chests.tres`, a `ChestSpread` of `chest_loot.tres`), sealed until the floor is cleared, and every guarded depth the Warden's Hoard (`hoard_loot.tres`), both holding more the deeper: potions, the creatures' remains to sell and coins, with what the bag cannot hold left inside for later
- Stairs down and the rope back to camp open once every enemy of the floor is defeated
- A cleared floor lights its ember altar: the player takes one of three boons for the run (the roguelite module's `BoonData`, `BoonAltar`), a sharper blade, faster feet, a quicker dodge, tougher skin, a ward that has burns and the slime's hold last half as long (`affliction_seconds`), kindling that has a quarter of the player's blows and shots set foes Burning, half when taken twice (the game's `burn_chance` stat, Burning's `AfflictionData.chance_stat`), more health, a heal or coins, and two more once the player reached depth 10 or became a Slayer, each run's offers rolled from its own stream, and the player may reroll a floor's offer once for 30 coins; from depth 2 about one unguarded floor in four has the Ember Peddler wait there once it is cleared (`game/data/shops/ember_peddler.tres`, a shop whose `DepthBoonOffer` sells one boon of the run for 60 coins, never Ember Tithe's coins, once a depth, beside potions dearer than at camp); the HUD lists the run's boons
- Back at camp, after a return or a defeat, the camp tells the run's report: the depth it reached, the creatures it defeated and its boons, a new best marked (the roguelite module's `RunTallyData`, `RunSummary`); the most creatures of any run is a record, and 15 in one run is Ember Rampage
- Every fifth depth a world reached is a shortcut: once there is one, the way down asks where the run starts, at the top or at a shortcut (`DepthRun.get_shortcuts()`)
- After the first run the way down offers pacts, boons of the pool `pact` that carry a burden with their reward: Ash (foes hit harder, drop more), Glass (a harder blade, less health) and, once the player is a Delver, Greed (twice the drops, a softer blade); reaching depth 10 under Glass is Unbroken Glass
- Each trip down is a run of the roguelite module (`RunState`), from the way down until the rope back or a defeat; the game saves only between runs, at camp, and a defeat costs a quarter of the player's money
- Combat experience and fourteen achievements (`game/data/achievements/`), unlocked by triggers in `game/data/triggers/`: Slayer counts every creature defeated in any run, and the title and the pause menu show how far the player is; Warden's Bane needs no trigger, it counts the bestiary's Ember Wardens (`progress_flag = "defeated:ember_warden"`); Elite Hunter counts the elites defeated in every run (`CombatEvents.elite_defeated`); Know Thy Foe counts the kinds the bestiary has met (`progress_flag = "kinds_defeated"`); Treasure Hunter counts the chests opened in every run (`ItemsEvents.chest_opened`), which a run's report and the Records show too; the deepest depth any save reached stays in the player's profile, and the achievements menu's Records shows it with the creatures defeated
- The pause menu shows what the delver carries (with where to get more), their combat skill, the bestiary of every kind of creature they have defeated across every save, the reports of their last ten runs and the bonuses of the run
- A clock that stands still: a day passes when the player rests or is defeated

Everything except the floors is the foundation's: the title, pause and settings menus, the hotbar, the melee attack, the dodge roll, the enemies, the shop, the runs and the depth track, saving, the profile and the triggers.
