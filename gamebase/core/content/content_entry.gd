class_name ContentEntry
extends Resource

## Base of every content definition (items, locations, quests, ...).
##
## A content entry is found by its `id`, which saves store, so an id is never
## reused for a different thing. To rename an entry, give it the new id and list
## the old one in `former_ids`: `ContentRegistry` then resolves saves and data
## that still use the old id to the renamed entry.

## Stable identity of the entry within its kind.
@export var id: StringName
## Ids this entry had before it was renamed.
@export var former_ids: Array[StringName] = []
## Data a game or mod attaches without changing the entry's script, read with
## `get_custom_field()`. Values must be JSON-safe (numbers, strings, booleans,
## arrays and dictionaries of those).
@export var custom_fields: Dictionary = {}

func get_custom_field(key: StringName, default_value: Variant = null) -> Variant:
	return custom_fields.get(String(key), custom_fields.get(key, default_value))
