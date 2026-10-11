class_name ContentEntry
extends Resource

## Base of every content definition (items, locations, quests, ...).
##
## A content entry is found by its `id`, which saves store, so an id is never
## reused for a different thing.

## Stable identity of the entry within its kind.
@export var id: StringName
## Data a game or mod attaches without changing the entry's script, read with
## `get_custom_field()`. Values must be JSON-safe (numbers, strings, booleans,
## arrays and dictionaries of those).
@export var custom_fields: Dictionary = {}

func get_custom_field(key: StringName, default_value: Variant = null) -> Variant:
	return custom_fields.get(String(key), custom_fields.get(key, default_value))
