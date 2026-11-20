class_name RtsGoal
extends RefCounted

## The goal of a battle on an open field: ground that a side wins by holding
## (`RtsMapData.goal_area`, `RtsBattle.goal`): while the units standing in it,
## healers aside, are all friends, they hold it, and once units of the side
## that takes it (`taker`'s, its allies among them) held it `seconds` in all,
## at one go or over many, that side wins the battle. Its foes standing there
## keep it from that side, alone or among its units.

## The ground, in the field's units.
var area: Rect2
## The seconds of holding that win the battle.
var seconds: float
## The faction whose side takes the ground (`FactionData`).
var taker: StringName
## The first placed of the units that hold the ground now, or null while no
## side does.
var holder: RtsUnit
## The seconds the taking side has held the ground.
var held := 0.0

func _init(goal_area: Rect2, goal_seconds: float, taking_faction: StringName) -> void:
	area = goal_area.abs()
	seconds = maxf(goal_seconds, 0.0)
	taker = taking_faction

## How much of the holding that wins the battle the taking side has done,
## from 0 to 1.
func get_fraction() -> float:
	return clampf(held / seconds, 0.0, 1.0) if seconds > 0.0 else 1.0

## Whether `unit` fights on the side that takes the ground.
func takes(unit: RtsUnit) -> bool:
	return not FactionData.are_hostile(unit.faction, taker)

## Notes who holds the ground of `battle` for `passed` seconds; true once the
## taking side has held it long enough.
func step(battle: RtsBattle, passed: float) -> bool:
	holder = null
	var standing: Array[RtsUnit] = []
	for unit: RtsUnit in battle.get_units_in(area):
		if unit.data.heals():
			continue
		for other: RtsUnit in standing:
			if battle.are_foes(unit, other):
				return false
		standing.append(unit)
	if standing.is_empty():
		return false
	holder = standing[0]
	if not takes(holder):
		return false
	held += passed
	return held + 0.000001 >= seconds
