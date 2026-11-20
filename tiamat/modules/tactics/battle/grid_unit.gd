class_name GridUnit
extends RefCounted

## A unit in a grid battle (`AtbBattle`): what kind it is, its side, its cell,
## its health and its time gauge, what it has done on its turn, which of its
## actions still recharge (`BattleActionData.recharge_turns`), and whether it
## leads its side or fled the battle.

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
## It leads its side, which flees once it falls (`BattlePlacement.leader`).
var leader := false
## It fled the battle when its side's leader fell.
var fled := false
## What it has done on its turn so far.
var has_moved := false
var has_acted := false
## How many turns it has started.
var turns_taken := 0
# action id -> the turn it may take that action again on.
var _ready_on: Dictionary[StringName, int] = {}

func _init(unit_data: BattleUnitData, unit_faction: StringName, start_cell: Vector2i, unit_index := 0, controlled := false) -> void:
	data = unit_data
	faction = unit_faction
	cell = start_cell
	index = unit_index
	player_controlled = controlled
	health = Health.new(unit_data.max_health)

## Whether it is still in the battle: it has health left and has not fled.
func is_alive() -> bool:
	return not health.is_depleted() and not fled

## Starts its next turn: it has neither moved nor acted on it.
func start_turn() -> void:
	turns_taken += 1
	has_moved = false
	has_acted = false

## How many of its turns from now `action` is ready on: 0 while it may take
## it, 1 when it may on its next turn, and so on.
func turns_to_ready(action: BattleActionData) -> int:
	return maxi(int(_ready_on.get(action.id, 0)) - turns_taken, 0)

## Whether it may take `action` now, as far as recharging goes.
func is_ready(action: BattleActionData) -> bool:
	return turns_to_ready(action) == 0

## Notes that it took `action` on this turn, so it recharges.
func use(action: BattleActionData) -> void:
	if action.recharge_turns > 0:
		_ready_on[action.id] = turns_taken + action.recharge_turns + 1

## The share of its gauge filled, from 0 to 1.
func get_gauge_fraction() -> float:
	return clampf(gauge / AtbBattle.GAUGE_FULL, 0.0, 1.0)
