class_name RtsPlacement
extends Resource

## A unit a command battle starts with (`RtsMapData.placements`): which unit,
## on which side and where on the field, in pixels.

@export var unit_id: StringName
## Its side (`FactionData`).
@export var faction_id: StringName = FactionData.MONSTERS
@export var position := Vector2.ZERO
