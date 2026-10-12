class_name RtsUnitGrid
extends RefCounted

## The units of a command battle (`RtsBattle`) filed by their side
## (`RtsUnit.side`) and by the square cell of the field each stands in, so a
## unit finds the ones near it (the foes it sees, the units it overlaps)
## without looking at every other one.

## The side of a cell, in pixels.
var cell_size: float
# For each side, cell -> the units of the side filed in it, in the order filed.
var _sides: Array[Dictionary] = []
# For each side, its units in the order filed, and the first and last cell
# that holds one.
var _units: Array[Array] = []
var _first: Array[Vector2i] = []
var _last: Array[Vector2i] = []

func _init(side: float) -> void:
	cell_size = maxf(side, 1.0)

## Files `units`, of sides below `side_count`, by where they stand now,
## forgetting where any stood before.
func fill(units: Array[RtsUnit], side_count: int) -> void:
	_sides.resize(side_count)
	_units.resize(side_count)
	_first.resize(side_count)
	_last.resize(side_count)
	for side: int in side_count:
		_sides[side] = {}
		_units[side] = []
		_first[side] = Vector2i(2147483647, 2147483647)
		_last[side] = -_first[side]
	for unit: RtsUnit in units:
		var side := unit.side
		var cell := _cell_of(unit.position)
		var filed: Variant = _sides[side].get(cell)
		if filed == null:
			_sides[side][cell] = [unit]
		else:
			(filed as Array).append(unit)
		_units[side].append(unit)
		_first[side] = _first[side].min(cell)
		_last[side] = _last[side].max(cell)

## The units of `sides` filed in the cells that `point` reaches within
## `reach` either way: each unit that stood that near when filed, and some
## farther (all of a side that has fewer units than such cells). Always in the
## same order for the same filing; a side that joined after it has none.
func get_near(point: Vector2, reach: float, sides: PackedInt32Array) -> Array[RtsUnit]:
	var near: Array[RtsUnit] = []
	var first := _cell_of(point - Vector2(reach, reach))
	var last := _cell_of(point + Vector2(reach, reach))
	for side: int in sides:
		if side >= _units.size() or _units[side].is_empty():
			continue
		var low := first.max(_first[side])
		var high := last.min(_last[side])
		if low.x > high.x or low.y > high.y:
			continue
		if (high.x - low.x + 1) * (high.y - low.y + 1) >= _units[side].size():
			near.append_array(_units[side])
			continue
		var cells := _sides[side]
		for y: int in range(low.y, high.y + 1):
			for x: int in range(low.x, high.x + 1):
				var filed: Variant = cells.get(Vector2i(x, y))
				if filed != null:
					near.append_array(filed)
	return near

func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
