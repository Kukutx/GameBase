class_name PersistentWorldState
extends Node

## The world's memory for one game: named values (flags, counters and the state
## of things in the world) that content and services keep under a key, such as
## a rule's `SET_FLAG` or a farm plot's crop. Many module services keep all
## their state here rather than in a save section of their own.
##
## The values are saved with the game and a new game clears them all; what
## outlives every save belongs in `GameProfile`. The save is JSON, so keep plain
## values (booleans, numbers, text, arrays, dictionaries), and read counters with
## `get_int()`: a saved whole number comes back as a float. `changed` fires with
## the key and its new value, or with an empty key when the whole world was
## cleared or loaded.

signal changed(key: StringName, value: Variant)

var _flags: Dictionary = {}

func set_value(key: StringName, value: Variant) -> void:
	if key == &"":
		return
	var string_key := String(key)
	if _flags.has(string_key):
		var current: Variant = _flags[string_key]
		# GDScript equality can raise on incompatible operand types (for example
		# int == Dictionary). Compare only like-typed values so repairing a corrupt
		# WorldState field can safely replace its previous representation.
		if typeof(current) == typeof(value) and current == value:
			return
	_flags[string_key] = value
	changed.emit(key, value)

## Whether the world holds a value under `key`, null included.
func has_value(key: StringName) -> bool:
	return _flags.has(String(key))

## The value under `key`, as the world holds it: a dictionary or an array is
## not a copy, so read it and set a new one rather than changing it in place.
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _flags.get(String(key), default_value)

## The keys the world holds a value under that begin with `prefix`.
func get_keys(prefix := "") -> Array[StringName]:
	var result: Array[StringName] = []
	for key: String in _flags:
		if key.begins_with(prefix):
			result.append(StringName(key))
	return result

func get_bool(key: StringName, default_value := false) -> bool:
	var raw: Variant = get_value(key, default_value)
	return bool(raw) if raw is bool else default_value

## A counter stored under `key`; saved numbers come back as floats, so read
## counters through this instead of `get_value`. A value that is not a whole
## number, as a hand-edited save can hold, reads as `default_value`.
func get_int(key: StringName, default_value := 0) -> int:
	var number: Variant = SaveValues.whole_number(get_value(key, default_value))
	return default_value if number == null else int(number)

## Adds `delta` to the counter under `key` and returns the new value.
func add_int(key: StringName, delta: int) -> int:
	var value := get_int(key) + delta
	set_value(key, value)
	return value

func erase(key: StringName) -> void:
	if _flags.erase(String(key)):
		changed.emit(key, null)

func clear() -> void:
	if _flags.is_empty():
		return
	_flags.clear()
	changed.emit(&"", null)

func to_save_data() -> Dictionary:
	return _flags.duplicate(true)

## The value under `key` that `snapshot`, a save, holds in its world (as the
## save holds it: read whole numbers with `SaveValues`), or null.
static func read_saved(snapshot: Dictionary, key: StringName) -> Variant:
	var world: Variant = snapshot.get("world", {})
	return (world as Dictionary).get(String(key)) if world is Dictionary else null

func load_save_data(data: Dictionary) -> void:
	_flags = data.duplicate(true)
	changed.emit(&"", null)
