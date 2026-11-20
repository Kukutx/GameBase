class_name RtsArrivals
extends RefCounted

## The units on their way to a command battle (`RtsBattle.add_arrival()`),
## the soonest first; of two due at once, the one added first.

## A unit on its way: its kind, its faction and the battle's side for it
## (`RtsSides`), the point it arrives at and the seconds of battle it arrives
## at.
class Arrival:
	var data: RtsUnitData
	var faction: StringName
	var side: int
	var point: Vector2
	var seconds: float

var _queue: Array[Arrival] = []

## Adds a unit of `data` on `faction`'s side (`side` in the battle) that
## arrives at `point` once `seconds` of battle have passed.
func add(data: RtsUnitData, faction: StringName, side: int, point: Vector2, seconds: float) -> void:
	var arrival := Arrival.new()
	arrival.data = data
	arrival.faction = faction
	arrival.side = side
	arrival.point = point
	arrival.seconds = seconds
	_queue.insert(_queue.bsearch_custom(arrival, func(a: Arrival, b: Arrival) -> bool: return a.seconds < b.seconds, false), arrival)

## How many units are on their way.
func size() -> int:
	return _queue.size()

## The seconds of battle the next unit arrives at, or INF when none is on its
## way.
func get_next() -> float:
	return _queue[0].seconds if not _queue.is_empty() else INF

## The units on their way, the soonest first.
func get_all() -> Array[Arrival]:
	return _queue.duplicate()

## The battle's sides of the units on their way that fight (healers aside),
## each once.
func get_fighting_sides() -> PackedInt32Array:
	var sides := PackedInt32Array()
	for arrival: Arrival in _queue:
		if not arrival.data.heals() and not sides.has(arrival.side):
			sides.append(arrival.side)
	return sides

## Takes the units due by `time` off the way, the soonest first.
func take_due(time: float) -> Array[Arrival]:
	var due: Array[Arrival] = []
	while not _queue.is_empty() and _queue[0].seconds <= time:
		due.append(_queue.pop_front())
	return due
