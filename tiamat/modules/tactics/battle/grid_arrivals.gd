class_name GridArrivals
extends RefCounted

## The units on their way to a grid battle (`AtbBattle.add_arrival()`), the
## soonest first; of two due at once, the one added first.

## A unit on its way: its kind, its faction, the cell it arrives in (or the
## open cell nearest it), whether it leads its side, and the seconds of
## battle time it arrives at.
class Arrival:
	var data: BattleUnitData
	var faction: StringName
	var cell: Vector2i
	var leader := false
	var seconds: float

var _queue: Array[Arrival] = []

## Adds a unit of `data` on `faction`'s side that arrives in `cell` once
## `seconds` of battle time have passed, leading its side with `leader`.
func add(data: BattleUnitData, faction: StringName, cell: Vector2i, seconds: float, leader := false) -> void:
	var arrival := Arrival.new()
	arrival.data = data
	arrival.faction = faction
	arrival.cell = cell
	arrival.leader = leader
	arrival.seconds = seconds
	_queue.insert(_queue.bsearch_custom(arrival, func(a: Arrival, b: Arrival) -> bool: return a.seconds < b.seconds, false), arrival)

## How many units are on their way.
func size() -> int:
	return _queue.size()

## The seconds of battle time the next unit arrives at, or INF when none is
## on its way.
func get_next() -> float:
	return _queue[0].seconds if not _queue.is_empty() else INF

## The units on their way, the soonest first.
func get_all() -> Array[Arrival]:
	return _queue.duplicate()

## The factions of the units on their way, each once.
func get_factions() -> Array[StringName]:
	var factions: Array[StringName] = []
	for arrival: Arrival in _queue:
		if not factions.has(arrival.faction):
			factions.append(arrival.faction)
	return factions

## Turns back the units of `faction` on their way, as when its side flees.
func remove_faction(faction: StringName) -> void:
	_queue = _queue.filter(func(arrival: Arrival) -> bool: return arrival.faction != faction)

## Places the unit of `arrival` in `battle`, leading its side as it does, in
## its cell or the open cell nearest it that no unit stands in; null while
## every cell is taken.
static func place(battle: AtbBattle, arrival: Arrival) -> GridUnit:
	var grid := battle.grid
	for reach: int in maxi(grid.size.x, grid.size.y) * 2:
		for cell: Vector2i in grid.cells_in_range(arrival.cell, reach, reach):
			if grid.is_open(cell) and battle.get_unit_at(cell) == null:
				var unit := battle.add_unit(arrival.data, arrival.faction, cell)
				unit.leader = arrival.leader
				return unit
	return null

## Takes the units due by `time` off the way, the soonest first.
func take_due(time: float) -> Array[Arrival]:
	var due: Array[Arrival] = []
	while not _queue.is_empty() and _queue[0].seconds <= time:
		due.append(_queue.pop_front())
	return due
