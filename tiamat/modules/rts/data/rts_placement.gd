class_name RtsPlacement
extends Resource

## A unit of a command battle (`RtsMapData.placements`): which unit, on which
## side and where on the field, in pixels, and when it joins: a reinforcement
## once another battle is won (`MINIGAME_WON ford_battle`), a foe more on a
## harder choice. A unit may also arrive while the battle runs
## (`arrive_seconds`), at its place: a band that comes to help one side.

@export var unit_id: StringName
## Its side (`FactionData`).
@export var faction_id: StringName = FactionData.MONSTERS
@export var position := Vector2.ZERO
## When the unit joins the battle: a `GameRules` query read as the battle
## starts; empty, always.
@export var condition := ""
## The seconds into the battle the unit arrives (`RtsBattle.add_arrival()`);
## 0, it is there as the battle starts.
@export_range(0.0, 600.0, 1.0, "suffix:s") var arrive_seconds := 0.0

## Whether the unit joins a battle that starts now.
func joins() -> bool:
	return GameRules.check(condition)
