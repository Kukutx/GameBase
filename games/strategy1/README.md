# Iron Banners

The third game built on Tiamat, of a third genre: strategy. From a camp the player plans a battle on a war table and fights it on a grid in active time, or leads the troops from the muster into a battle in real time on an open field, commanding their banner's units against raiders. It uses only the core and the `damage`, `rts` and `tactics` modules (no items), and keeps the foundation honest for a game whose fights are turns on a grid or orders to troops rather than swings in the world.

## Run

From the repository root, link the foundation and the addons once, then open `games/strategy1/project.godot` in Godot:

```text
node tools/link.js --game strategy1
```

The main scene is the core title screen, `res://tiamat/core/ui/title_screen.tscn`. `node tools/validate.js --game strategy1` runs this game's checks; its runtime check picks the battles at the ford, the mill, the watchtower and in the pass and walks the camp, and ends with `Camp smoke passed.`. The version lives in `config/version` of `project.godot`; a release is the tag `game/strategy1/v<version>`.

## Layout

```text
game/data/         Data resources, listed in the content pack content.tres
game/data/tactics/ The battles at the ford, the mill and the watchtower: their maps, the units of both sides, their actions and the minigames
game/data/rts/     The battles in the pass and at the raider camp: their maps, the units of both sides and the minigames
game/world/        The camp, with the war table and the muster, and the lookout
game/player/       The player scene and controller
game/ui/           The HUD, which holds the core pause menu
game/i18n/         The Simplified Chinese catalog of the game's own text
game/game_setup.gd The game's own module
test/unit/         The maps of the five battles, and a battle on each fought to its end
test/runtime/      The camp smoke: the war table, the muster, the lookout, sleep, save and load
```

## Gameplay

- The war table in the camp (a core `MiniGameStation`) lists its battles, the tactics module's `GridBattleGame`: the Border Ford, the Old Mill once the ford is won (`MINIGAME_WON ford_battle`) and the Watchtower once the mill is taken; a battle won is marked in the list, with the most units the player had left at its end and the stars that earned (`score_goals`: three for each battle, the third at the ford for losing no one), and the score the next star needs
- A river that only the ford crosses, rocks, woods on both banks that give cover (a unit there takes 30% less damage, and the board and the side say so), a ford that takes two steps to wade into, and four of the player's units (two swordsmen whose shield bash sets a foe's turn back, an archer whose volley rains on an area, a cleric who mends one or prays over a few) against four raiders (two raiders, a brute whose quake shakes all around it, a slinger whose firepots burn an area); a shield bash, a volley, a quake and a prayer must recharge for some of their user's turns (`BattleActionData.recharge_turns`), and their command tells when they are ready
- Every unit's gauge fills at its speed; on its turn a unit moves and acts once each, and one that skips either comes back sooner
- Time stands still while the player picks a command; cancel twice gives the battle up
- At the Old Mill a stream crosses the field below the mill, with a bridge and a ford over it, the mill's ruins and the woods giving cover and its ford slower to cross than the bridge, and five of the player's units (an archer more) against seven raiders led by a Warlord, whose fall sends the rest fleeing (`BattlePlacement.leader`), so a bold strike at the mill can end the battle early; a win in the pass sends a swordsman more, and a win at the ford two spearmen more to the Raider Camp (placements with a `condition`), so the two lines of battles help each other
- At the Watchtower raiders storm the tower to light its beacon: its walls leave two doors, the player's two swordsmen stand in them with an archer and a cleric sheltered inside, and seven raiders (a brute and two slingers among them) come over a ditch; a raider who ends a turn on the beacon lights it and the battle is lost (`BattleMapData.goal_cells`, taken by the raiders, `goal_faction_id`), so the doors must hold, or a unit of the player's must stand on the beacon itself; a storm of the Raider Camp sends an archer more
- The muster (another `MiniGameStation`) lists the rts module's `RtsBattleGame` battles: the Hill Pass, two hills with a pass between, and nine of the player's units (spearmen, bowmen, riders) against ten raiders (raiders, brutes, slingers) who march on them, each side with its counters (`RtsUnitData.strong_against`, told on a selection of one kind): riders run down slingers, spears hold off brutes and raiders hunt bowmen and medics, hitting harder and going after them first; and, once the pass is won, the Raider Camp, where twelve raiders wait behind a palisade with one gate for the player to storm and the fire at its heart to hold for 20 seconds, which wins the battle as surely as defeating them all (`RtsMapData.hold_area`), with a Field Medic among the player's troops who mends the most hurt of them it sees (the rts module's `RtsUnitData.heal`)
- The player selects units with clicks or a box and orders them with a right click, or with the bar and its keys: attack-move, stop, hold, all, and groups on Ctrl and a digit; holding the pass beats charging through it
- Nine achievements (`game/data/achievements/`): a win at each of the five battles, Veteran for 50 raiders defeated across every battle, a win with the foe strength on Strong (the settings offer each battle's foe strength and speed), Master of the Field for every star of the five battles (`MINIGAME_STARS`), and a hidden one for winning the ford and the pass; the title and the pause menu list them, with the battles won and the raiders defeated under Records

Everything but the maps, their units and the achievements is the foundation's: the title, pause, settings and achievements menus, the war table and the muster, both battles, their boards and their foes' play, saving and the profile.
