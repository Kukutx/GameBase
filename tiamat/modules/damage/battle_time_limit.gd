class_name BattleTimeLimit
extends RefCounted

## A battle's time limit, on a grid or on an open field: once `seconds` of
## battle time have passed, the battle ends, won by the side of `faction`
## (`FactionData`), its allies among it. Theirs is a stand the player wins by
## holding out until then; their foes', a raid the player loses unless they
## win it sooner.

# Seconds of battle time short of the limit that still reach it, so rounding
# never leaves a battle running past it.
const _EPSILON := 0.000001

## The seconds of battle time the battle lasts at most.
var seconds: float
## The faction whose side wins once time runs out.
var faction: StringName

func _init(limit_seconds: float, winning_faction: StringName) -> void:
	seconds = maxf(limit_seconds, 0.0)
	faction = winning_faction

## The seconds of battle time left at `time`, no fewer than 0.
func get_left(time: float) -> float:
	return maxf(seconds - time, 0.0)

## Whether time has run out at `time`.
func is_up(time: float) -> bool:
	return time + _EPSILON >= seconds

## Whether the side of `side_faction` wins once time runs out.
func wins(side_faction: StringName) -> bool:
	return not FactionData.are_hostile(faction, side_faction)
