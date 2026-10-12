class_name WorldValueInheritance
extends InheritanceRule

## Carries the world's values whose keys begin with one of `prefixes` over
## (`WorldState`): what the next playthrough or a sequel remembers, such as a
## secret found or a door once opened. Only booleans, numbers and text carry.

@export var prefixes: PackedStringArray = []

func _init() -> void:
	key = &"world"

func capture() -> Variant:
	var values: Dictionary = {}
	for prefix: String in prefixes:
		if prefix.is_empty():
			continue
		for world_key: StringName in WorldState.get_keys(prefix):
			var value: Variant = WorldState.get_value(world_key)
			if _carries(value):
				values[String(world_key)] = value
	return values

func apply(data: Variant) -> void:
	if not data is Dictionary:
		return
	var values: Dictionary = data
	for raw_key: Variant in values:
		var world_key := String(raw_key)
		if _matches(world_key) and _carries(values[raw_key]):
			WorldState.set_value(StringName(world_key), values[raw_key])

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if prefixes.is_empty():
		problems.append("carries no world value (it has no prefixes)")
	if prefixes.has(""):
		problems.append("has an empty prefix, which would carry the whole world")
	return problems

func _matches(world_key: String) -> bool:
	for prefix: String in prefixes:
		if not prefix.is_empty() and world_key.begins_with(prefix):
			return true
	return false

static func _carries(value: Variant) -> bool:
	return value is bool or value is int or value is float or value is String
