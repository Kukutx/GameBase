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
## in every save. An empty vital id
## names none: spending it costs nothing, which is how a game without energy
## makes tools free. An id the game's content does not know reads as 0 and
## changes nothing.

signal changed(vital_id: StringName, current: int, maximum: int)
signal depleted(vital_id: StringName)

var _values: Dictionary[StringName, int] = {}
var _maximums: Dictionary[StringName, int] = {}

## Whether the game has the vital `vital_id`.
func has_vital(vital_id: StringName) -> bool:
	return _ensure(vital_id)

func get_value(vital_id: StringName) -> int:
	return _values[vital_id] if _ensure(vital_id) else 0

func get_maximum(vital_id: StringName) -> int:
	return _maximums[vital_id] if _ensure(vital_id) else 0

## The share of the maximum left, from 0 to 1.
func get_fraction(vital_id: StringName) -> float:
	return float(get_value(vital_id)) / float(get_maximum(vital_id)) if _ensure(vital_id) else 0.0

func is_full(vital_id: StringName) -> bool:
	return _ensure(vital_id) and _values[vital_id] >= _maximums[vital_id]

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
		_change(vital_id, clampi(amount, 0, _maximums[vital_id]))

## Raises the vital by `amount`, up to its maximum; returns how much it rose.
func restore(vital_id: StringName, amount: int) -> int:
	if amount <= 0 or not _ensure(vital_id):
		return 0
	var before := _values[vital_id]
	_change(vital_id, mini(before + amount, _maximums[vital_id]))
	return _values[vital_id] - before

## Fills the vital to its maximum.
func refill(vital_id: StringName) -> void:
	if _ensure(vital_id):
		_change(vital_id, _maximums[vital_id])

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
	var value := mini(_values[vital_id], _maximums[vital_id])
	_values[vital_id] = value
	changed.emit(vital_id, value, _maximums[vital_id])

## Fills every vital at its starting maximum.
func reset_new_game() -> void:
	_values.clear()
	_maximums.clear()
	for vital: VitalData in VitalData.find_all():
		_ensure(vital.id)
		changed.emit(vital.id, _values[vital.id], _maximums[vital.id])

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
		_values[vital.id] = clampi(SaveValues.whole_number_or(section.get("value", maximum), maximum), 0, maximum)
		changed.emit(vital.id, _values[vital.id], maximum)

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
	return true

func _change(vital_id: StringName, value: int) -> void:
	if value == _values[vital_id]:
		return
	_values[vital_id] = value
	changed.emit(vital_id, value, _maximums[vital_id])
	if value == 0:
		depleted.emit(vital_id)
