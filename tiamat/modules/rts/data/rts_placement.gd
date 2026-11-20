class_name RtsPlacement
extends Resource

## A unit a command battle starts with (`RtsMapData.placements`): which unit,
## on which side and where on the field, in pixels, and when it joins: a
## reinforcement once another battle is won (`MINIGAME_WON ford_battle`), a
## foe more on a harder choice.

@export var unit_id: StringName
## Its side (`FactionData`).
@export var faction_id: StringName = FactionData.MONSTERS
@export var position := Vector2.ZERO
## When the unit joins the battle: a `GameRules` query read as the battle
## starts; empty, always.
@export var condition := ""

## Whether the unit joins a battle that starts now.
func joins() -> bool:
	return GameRules.check(condition)
