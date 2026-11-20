class_name PlayerVitals
extends Node

## The player's vitals (`VitalData`), each between 0 and its maximum: work and
## attacks spend them (`spend()`, `try_spend()`), food and rest restore them,
## enemies drain them. The HUD follows `changed`; `depleted` fires when one
## reaches 0, and what follows (a defeat at no health) belongs to the module
## that owns the vital.
##
## A vital starts full at its `VitalData.maximum`, and a new game fills them
## all again; the save keeps each one's value and how far its maximum is from
## the vital's own (an upgrade), so a game that changes a maximum changes it
## in every save. A vital whose maximum follows a stat (`VitalData.maximum_stat`:
## a boon, a lasting upgrade) reads it again when the stats change
## (`GameStats.changed`): a maximum that rises comes filled, the value rising
## with it, and one that falls takes the value down to it. An empty vital id
## names none: spending it costs nothing, which is how a game without energy
## makes tools free. An id the game's content does not know reads as 0 and
## changes nothing.

signal changed(vital_id: StringName, current: int, maximum: int)
signal depleted(vital_id: StringName)

# The most a save may hold of a vital whose maximum follows a stat, until the
# stats are read.
const MAX_FOLLOWING_VALUE := 999999

var _values: Dictionary[StringName, int] = {}
# Each vital's own maximum, with what `set_maximum()` changed, before stats.
var _maximums: Dictionary[StringName, int] = {}
# The maximum `changed` last told of each vital that follows a stat; none once
# a save loaded, until the stats are read again.
var _shown: Dictionary[StringName, int] = {}

func _ready() -> void:
	GameStats.changed.connect(_follow_stats)

## Whether the game has the vital `vital_id`.
func has_vital(vital_id: StringName) -> bool:
	return _ensure(vital_id)

func get_value(vital_id: StringName) -> int:
	return _values[vital_id] if _ensure(vital_id) else 0

## The vital's maximum now: its own, changed by the stat it follows.
func get_maximum(vital_id: StringName) -> int:
	if not _ensure(vital_id):
		return 0
	var vital := VitalData.find(vital_id)
	if vital == null or vital.maximum_stat == &"":
		return _maximums[vital_id]
	return maxi(roundi(GameStats.apply(vital.maximum_stat, _maximums[vital_id])), 1)

## The share of the maximum left, from 0 to 1.
func get_fraction(vital_id: StringName) -> float:
	return float(get_value(vital_id)) / float(get_maximum(vital_id)) if _ensure(vital_id) else 0.0

func is_full(vital_id: StringName) -> bool:
	return _ensure(vital_id) and _values[vital_id] >= get_maximum(vital_id)

## The vital as the player reads it, translated: its name and how much of it
## is left ("Energy 80/100"); "" for a vital the game does not have.
func describe(vital_id: StringName) -> String:
	var vital := VitalData.find(vital_id)
	if vital == null:
		return ""
	return "%s %d/%d" % [tr(vital.display_name), get_value(vital_id), get_maximum(vital_id)]

## Every vital of the game as `describe()` reads it, in id order.
func describe_all() -> PackedStringArray:
	var lines := PackedStringArray()
	for vital: VitalData in VitalData.find_all():
		lines.append(describe(vital.id))
	return lines

## Sets the vital to `amount`, kept between 0 and its maximum.
func set_value(vital_id: StringName, amount: int) -> void:
	if _ensure(vital_id):
		_change(vital_id, clampi(amount, 0, get_maximum(vital_id)))

## Raises the vital by `amount`, up to its maximum; returns how much it rose.
func restore(vital_id: StringName, amount: int) -> int:
	if amount <= 0 or not _ensure(vital_id):
		return 0
	var before := _values[vital_id]
	_change(vital_id, mini(before + amount, get_maximum(vital_id)))
	return _values[vital_id] - before

## Fills the vital to its maximum.
func refill(vital_id: StringName) -> void:
	if _ensure(vital_id):
		_change(vital_id, get_maximum(vital_id))

## Fills every vital that a night's sleep fills (`VitalData.refill_on_sleep`).
func refill_after_sleep() -> void:
	for vital: VitalData in VitalData.find_all():
		if vital.refill_on_sleep:
			refill(vital.id)

## Takes `amount` of the vital for something that costs it: false, and nothing
## taken, when there is not that much. Free (true) for an empty id, an amount
## of 0 or less, or a vital the game does not have.
func spend(vital_id: StringName, amount: int) -> bool:
	if amount <= 0 or not _ensure(vital_id):
		return true
	if _values[vital_id] < amount:
		return false
	_change(vital_id, _values[vital_id] - amount)
	return true

## `spend()`, telling the player when there is not enough ("Not enough
## Energy").
func try_spend(vital_id: StringName, amount: int) -> bool:
	if spend(vital_id, amount):
		return true
	var vital := VitalData.find(vital_id)
	GameEvents.toastf("Not enough %s", [tr(vital.display_name) if vital != null else String(vital_id)])
	return false

## Takes up to `amount` of the vital, down to 0 (a hit); returns how much it
## took. `depleted` follows when it reaches 0.
func drain(vital_id: StringName, amount: int) -> int:
	if amount <= 0 or not _ensure(vital_id) or _values[vital_id] <= 0:
		return 0
	var before := _values[vital_id]
	_change(vital_id, maxi(before - amount, 0))
	return before - _values[vital_id]

## Sets the vital's maximum (an upgrade), keeping its value within it.
func set_maximum(vital_id: StringName, maximum: int) -> void:
	if not _ensure(vital_id):
		return
	_maximums[vital_id] = maxi(maximum, 1)
	var value := mini(_values[vital_id], get_maximum(vital_id))
	_values[vital_id] = value
	_shown[vital_id] = get_maximum(vital_id)
	changed.emit(vital_id, value, _shown[vital_id])

## Fills every vital at its starting maximum.
func reset_new_game() -> void:
	_values.clear()
	_maximums.clear()
	_shown.clear()
	for vital: VitalData in VitalData.find_all():
		_ensure(vital.id)
		changed.emit(vital.id, _values[vital.id], get_maximum(vital.id))

func to_save_data() -> Dictionary:
	var data := {}
	for vital: VitalData in VitalData.find_all():
		if _ensure(vital.id):
			data[String(vital.id)] = {"value": _values[vital.id], "bonus": _maximums[vital.id] - vital.maximum}
	return data

## Restores what `to_save_data()` kept. A vital the save lacks (the game added
## it since) starts full.
func load_save_data(data: Dictionary) -> void:
	_values.clear()
	_maximums.clear()
	for vital: VitalData in VitalData.find_all():
		var saved: Variant = data.get(String(vital.id), {})
		var section: Dictionary = saved if saved is Dictionary else {}
		var maximum := maxi(vital.maximum + SaveValues.whole_number_or(section.get("bonus", 0), 0), 1)
		_maximums[vital.id] = maximum
		# What the stats make of a maximum that follows one is known once the
		# whole save loaded (the world's upgrades load after the vitals).
		var limit := maximum if vital.maximum_stat == &"" else MAX_FOLLOWING_VALUE
		_values[vital.id] = clampi(SaveValues.whole_number_or(section.get("value", maximum), maximum), 0, limit)
		changed.emit(vital.id, _values[vital.id], get_maximum(vital.id))
	_shown.clear()
	_follow_stats.call_deferred()

# Whether the game has `vital_id`, starting it full the first time it is asked
# for.
func _ensure(vital_id: StringName) -> bool:
	if _maximums.has(vital_id):
		return true
	if vital_id == &"":
		return false
	var vital := VitalData.find(vital_id)
	if vital == null:
		return false
	_maximums[vital_id] = maxi(vital.maximum, 1)
	_values[vital_id] = _maximums[vital_id]
	if vital.maximum_stat != &"":
		_shown[vital_id] = get_maximum(vital_id)
		_values[vital_id] = _shown[vital_id]
	return true

func _change(vital_id: StringName, value: int) -> void:
	if value == _values[vital_id]:
		return
	_values[vital_id] = value
	changed.emit(vital_id, value, get_maximum(vital_id))
	if value == 0:
		depleted.emit(vital_id)

# Reads again the maximum of each vital that follows a stat: one that rose
# raises the value as much, one that fell takes the value down to it, and
# `changed` tells of each that moved. After a save loaded, the value is only
# kept within the maximum.
func _follow_stats() -> void:
	for vital_id: StringName in _maximums.keys():
		var vital := VitalData.find(vital_id)
		if vital == null or vital.maximum_stat == &"":
			continue
		var maximum := get_maximum(vital_id)
		var before: int = _shown.get(vital_id, -1)
		var value := _values[vital_id]
		if before > 0 and maximum > before:
			value += maximum - before
		value = mini(value, maximum)
		_shown[vital_id] = maximum
		if maximum != before or value != _values[vital_id]:
			_values[vital_id] = value
			changed.emit(vital_id, value, maximum)
