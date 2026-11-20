class_name GridTurnOrder
extends RefCounted

## The order turns come in a grid battle (`AtbBattle.get_turn_order()`), as
## the gauges will fill.

const _EPSILON := 0.000001

## The units of `units` whose turns come after the one now, soonest first,
## `count` of them: the player's units in `waiting`, full, first, then each
## unit's turns in turn, every one of them as though the unit moved and acted
## (`turn`, the unit whose turn it is now, from an empty gauge); units that
## fill at the same moment in the order they were placed.
static func of(units: Array[GridUnit], waiting: Array[GridUnit], turn: GridUnit, count: int) -> Array[GridUnit]:
	var order: Array[GridUnit] = []
	# When each unit fills next, in battle time from now.
	var next: Dictionary[GridUnit, float] = {}
	for unit: GridUnit in units:
		if not unit.is_alive() or unit.data.speed <= 0.0:
			continue
		if waiting.has(unit):
			next[unit] = AtbBattle.GAUGE_FULL / unit.data.speed
		else:
			next[unit] = (AtbBattle.GAUGE_FULL - (0.0 if unit == turn else unit.gauge)) / unit.data.speed
	for unit: GridUnit in waiting:
		if order.size() < count:
			order.append(unit)
	while order.size() < count and not next.is_empty():
		var soonest: GridUnit = null
		for unit: GridUnit in next:
			if soonest == null or next[unit] < next[soonest] - _EPSILON or (next[unit] <= next[soonest] + _EPSILON and unit.index < soonest.index):
				soonest = unit
		order.append(soonest)
		next[soonest] += AtbBattle.GAUGE_FULL / soonest.data.speed
	return order
