class_name RtsTargets
extends RefCounted

## What a unit of a command battle (`RtsBattle`) goes after each step, as its
## order lets it. A fighter goes after a foe: the one it is ordered to attack,
## else the one it already fights while it stays near (`RtsBattle.LEASH`
## times its sight), else the nearest it sees; holding, only one it reaches;
## moving, none. A healer (`RtsUnitData.heal`) goes the same way after the
## most hurt friend instead, while that friend is still hurt.

## The unit `unit` fights, mends or goes to now; null when it has none.
static func choose(battle: RtsBattle, unit: RtsUnit) -> RtsUnit:
	if unit.data.heals():
		return _patient(battle, unit)
	var current := battle.get_unit(unit.target_index)
	match unit.order:
		RtsUnit.Order.MOVE:
			return null
		RtsUnit.Order.ATTACK:
			if current != null:
				return current
			unit.order = RtsUnit.Order.IDLE
			unit.clear_path()
		RtsUnit.Order.HOLD:
			if current != null and unit.reaches(current):
				return current
			return _take(unit, battle.get_nearest_foe(unit, unit.data.attack_range))
	if current != null and unit.get_gap_to(current) <= unit.data.sight_range * RtsBattle.LEASH:
		return current
	return _take(unit, battle.get_nearest_foe(unit, unit.data.sight_range))

static func _patient(battle: RtsBattle, healer: RtsUnit) -> RtsUnit:
	if healer.order == RtsUnit.Order.MOVE:
		return null
	var current := battle.get_unit(healer.target_index)
	var hurt := current != null and current.health.current < current.health.maximum and not battle.are_foes(healer, current)
	if healer.order == RtsUnit.Order.HOLD:
		if hurt and healer.reaches(current):
			return current
		return _take(healer, battle.get_most_hurt_friend(healer, healer.data.attack_range))
	if hurt and healer.get_gap_to(current) <= healer.data.sight_range * RtsBattle.LEASH:
		return current
	return _take(healer, battle.get_most_hurt_friend(healer, healer.data.sight_range))

# Makes `target` the one `unit` goes after (none when null), dropping its
# way when that changes.
static func _take(unit: RtsUnit, target: RtsUnit) -> RtsUnit:
	var index := target.index if target != null else -1
	if index != unit.target_index:
		unit.target_index = index
		unit.clear_path()
	return target
