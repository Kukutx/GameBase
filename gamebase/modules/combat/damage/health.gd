class_name Health
extends RefCounted

## Health that damage takes and healing gives back, between 0 and its maximum:
## a creature's or any other combatant's. (The player's own is a vital,
## `CombatSettings.health_vital_id`, which the save keeps.) `depleted` fires
## once it reaches 0.

signal changed(current: int, maximum: int)
signal depleted

var maximum := 1
var current := 1

func _init(max_health := 1) -> void:
	reset(max_health)

## Sets the maximum to `max_health` and fills the health, without a signal:
## the health of something that (re)appears.
func reset(max_health: int) -> void:
	maximum = maxi(max_health, 1)
	current = maximum

## Takes up to `amount`; the health lost.
func take(amount: int) -> int:
	if amount <= 0 or current <= 0:
		return 0
	var lost := mini(amount, current)
	set_current(current - lost)
	return lost

## Gives back up to `amount`; the health gained. Nothing heals what is
## depleted (it is revived with `set_current()` or `reset()`).
func heal(amount: int) -> int:
	if amount <= 0 or current <= 0:
		return 0
	var gained := mini(amount, maximum - current)
	set_current(current + gained)
	return gained

## Sets the health, kept between 0 and the maximum.
func set_current(value: int) -> void:
	var next := clampi(value, 0, maximum)
	if next == current:
		return
	current = next
	changed.emit(current, maximum)
	if current == 0:
		depleted.emit()

func is_depleted() -> bool:
	return current <= 0

## The share of the maximum left, from 0 to 1.
func get_fraction() -> float:
	return float(current) / float(maximum)
