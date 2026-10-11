class_name PersistentWorldState
extends Node

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

func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _flags.get(String(key), default_value)

func get_bool(key: StringName, default_value := false) -> bool:
	var raw: Variant = get_value(key, default_value)
	return bool(raw) if raw is bool else default_value

## A counter stored under `key`; saved numbers come back as floats, so read
## counters through this instead of `get_value`.
func get_int(key: StringName, default_value := 0) -> int:
	var raw: Variant = get_value(key, default_value)
	return int(raw) if raw is int or raw is float else default_value

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

func load_save_data(data: Dictionary) -> void:
	_flags = data.duplicate(true)
	changed.emit(&"", null)
