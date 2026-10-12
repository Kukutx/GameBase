class_name RtsUnit
extends RefCounted

## A unit in a command battle (`RtsBattle`): what kind it is, its side, where
## it stands, its health, the order it follows and the way it walks.

enum Order {
	## Nothing to do: it goes after the foes it sees.
	IDLE,
	## Walks to `goal`, passing foes by.
	MOVE,
	## Goes after the unit `target_index` until it falls.
	ATTACK,
	## Walks to `goal`, fighting the foes it sees on the way.
	ATTACK_MOVE,
	## Stays where it stands and fights only what it reaches from there.
	HOLD,
}

var data: RtsUnitData
var faction: StringName
## Its place among the battle's units (`RtsBattle.units`).
var index := 0
var position := Vector2.ZERO
var health: Health
## The player orders it.
var player_controlled := false
var order := Order.IDLE
## Where a move or an attack-move goes.
var goal := Vector2.ZERO
## The place among the battle's units of the unit it attacks, or -1: an index
## rather than the unit, so units never hold one another.
var target_index := -1
## The points it walks through, the next first, and where they lead.
var path := PackedVector2Array()
var path_end := Vector2.INF
## Seconds until it may attack again.
var cooldown := 0.0
## Seconds until it looks again for the way to the foe it goes after.
var repath_left := 0.0

func _init(unit_data: RtsUnitData, unit_faction: StringName, start: Vector2, unit_index := 0, controlled := false) -> void:
	data = unit_data
	faction = unit_faction
	position = start
	index = unit_index
	player_controlled = controlled
	health = Health.new(unit_data.max_health)

func is_alive() -> bool:
	return not health.is_depleted()

## How far its edge is from `other`'s.
func get_gap_to(other: RtsUnit) -> float:
	return position.distance_to(other.position) - data.radius - other.data.radius

## Whether `other` is in reach of its attacks.
func reaches(other: RtsUnit) -> bool:
	return get_gap_to(other) <= data.attack_range
