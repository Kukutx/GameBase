class_name BattlePlacement
extends Resource

## A unit of a grid battle (`BattleMapData.placements`): which unit, on which
## side and in which cell, and when it joins: a reinforcement once another
## battle is won (`MINIGAME_WON pass_battle`), a foe more on a harder choice
## (`OPTION foe_strength Strong`). A unit may also arrive while the battle
## runs (`arrive_seconds`), in its cell or the open one nearest it. A
## leader's side flees once the leader falls (`AtbBattle`).

@export var unit_id: StringName
## Its side (`FactionData`).
@export var faction_id: StringName = FactionData.MONSTERS
@export var cell := Vector2i.ZERO
## When the unit joins the battle: a `GameRules` query read as the battle
## starts; empty, always.
@export var condition := ""
## The seconds of battle time (`AtbBattle.time`, which stands still while
## the player chooses unless it flows) the unit arrives at; 0, it is there as
## the battle starts.
@export_range(0.0, 600.0, 1.0, "suffix:s") var arrive_seconds := 0.0
## The unit leads its side: once it falls, the rest of its faction flees the
## battle.
@export var leader := false

## Whether the unit joins a battle that starts now.
func joins() -> bool:
	return GameRules.check(condition)
