class_name BattlePlacement
extends Resource

## A unit a grid battle starts with (`BattleMapData.placements`): which unit,
## on which side and in which cell.

@export var unit_id: StringName
## Its side (`FactionData`).
@export var faction_id: StringName = FactionData.MONSTERS
@export var cell := Vector2i.ZERO
