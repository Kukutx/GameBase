class_name BattlePlacement
extends Resource

## A unit a grid battle starts with (`BattleMapData.placements`): which unit,
## on which side and in which cell, and when it joins: a reinforcement once
## another battle is won (`MINIGAME_WON pass_battle`), a foe more on a harder
## choice (`OPTION foe_strength Strong`). A leader's side flees once the
## leader falls (`AtbBattle`).

@export var unit_id: StringName
## Its side (`FactionData`).
@export var faction_id: StringName = FactionData.MONSTERS
@export var cell := Vector2i.ZERO
## When the unit joins the battle: a `GameRules` query read as the battle
## starts; empty, always.
@export var condition := ""
## The unit leads its side: once it falls, the rest of its faction flees the
## battle.
@export var leader := false

## Whether the unit joins a battle that starts now.
func joins() -> bool:
	return GameRules.check(condition)
