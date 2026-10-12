class_name GridUnit
extends RefCounted

## A unit in a grid battle (`AtbBattle`): what kind it is, its side, its cell,
## its health and its time gauge, and what it has done on its turn.

var data: BattleUnitData
var faction: StringName
var cell: Vector2i
var health: Health
## From 0 to `AtbBattle.GAUGE_FULL`, where its turn comes.
var gauge := 0.0
## The player commands it.
var player_controlled := false
## Its place among the battle's units: on a tie, the earlier goes first.
var index := 0
## What it has done on its turn so far.
var has_moved := false
var has_acted := false

func _init(unit_data: BattleUnitData, unit_faction: StringName, start_cell: Vector2i, unit_index := 0, controlled := false) -> void:
	data = unit_data
	faction = unit_faction
	cell = start_cell
	index = unit_index
	player_controlled = controlled
	health = Health.new(unit_data.max_health)

func is_alive() -> bool:
	return not health.is_depleted()

## The share of its gauge filled, from 0 to 1.
func get_gauge_fraction() -> float:
	return clampf(gauge / AtbBattle.GAUGE_FULL, 0.0, 1.0)
