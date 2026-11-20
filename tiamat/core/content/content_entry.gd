class_name ContentEntry
extends Resource

## Base of every content definition (items, locations, quests, ...).
##
## A content entry is found by its `id`, which saves store, so an id is never
## reused for a different thing. Each kind of entry is a class that extends
## this one, declares its kind as a `KIND` constant and is registered with
## `ContentRegistry.register_kind()` by the module that defines it; its static
## `find()` and `find_all()` read the running game's entries of that kind.

## Stable identity of the entry within its kind.
@export var id: StringName
## Data a game or mod attaches without changing the entry's script, read with
## `get_custom_field()`. Values must be JSON-safe (numbers, strings, booleans,
## arrays and dictionaries of those).
@export var custom_fields: Dictionary = {}

func get_custom_field(key: StringName, default_value: Variant = null) -> Variant:
	return custom_fields.get(String(key), custom_fields.get(key, default_value))

## Whether `a` comes before `b` in the lists the player reads of a kind whose
## entries have an `order` (`RecordData`, `AchievementData`,
## `MiniGameDefinition`): the lower order first, then by id; an entry without
## one stands at 0. A kind sorts its `find_all()` with it
## (`result.sort_custom(ContentEntry.listed_before)`), so content spaces its
## orders out (10, 20, 30) and a later entry slots in between.
static func listed_before(a: ContentEntry, b: ContentEntry) -> bool:
	var a_order := _order_of(a)
	var b_order := _order_of(b)
	return a_order < b_order or (a_order == b_order and String(a.id) < String(b.id))

static func _order_of(entry: ContentEntry) -> int:
	var value: Variant = entry.get(&"order")
	return value if value is int else 0

## What is wrong with this entry: its own fields and its references to other
## content of `registry`. Each problem reads after the entry's kind and id
## ("references unknown item 'x'"); the registry adds those.
func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	return PackedStringArray()
