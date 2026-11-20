class_name LootEntry
extends Resource

## One thing a find may hold (`LootTable`): a count of an item, as likely as
## its `weight` against the table's other entries, and only from its level on
## (a depth, a mine floor).

## The item it gives.
@export var item_id: StringName
## How likely it comes against the table's other entries; 0 never.
@export_range(0.0, 100.0, 0.1, "or_greater") var weight := 1.0
## How many it gives, from the least to the most.
@export_range(1, 999, 1) var min_quantity := 1
@export_range(1, 999, 1) var max_quantity := 1
## The first level it comes at; 0 any.
@export_range(0, 9999, 1, "or_greater") var from_level := 0

## An entry of `quantity` (from the least to the most, `[least, most]`, or one
## count) of item `id`, as likely as `weight`, from level `from` on.
static func of(id: StringName, quantity: Variant = 1, weight_of := 1.0, from := 0) -> LootEntry:
	var entry := LootEntry.new()
	entry.item_id = id
	entry.weight = weight_of
	var counts: Array = quantity if quantity is Array else [quantity, quantity]
	entry.min_quantity = int(counts[0])
	entry.max_quantity = int(counts[counts.size() - 1])
	entry.from_level = from
	return entry
