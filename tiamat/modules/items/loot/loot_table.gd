class_name LootTable
extends Resource

## What a find holds (a chest, `LootChest`, or anything else that hands one
## out): `picks` of its `entries`, drawn by weight among those its level
## reached (`LootEntry.from_level`), each entry at most once a find and each
## its count between its least and most; and money between `money_min` and
## `money_max`, `money_per_level` more each level past the first. The same
## stream (`GameRandomStream`) at the same level rolls the same find.

## What a roll found, or what is left of it: counts of items, by item id, and
## money.
class Find extends RefCounted:
	var items: Dictionary[StringName, int] = {}
	var money := 0

	## Whether it holds nothing.
	func is_empty() -> bool:
		return items.is_empty() and money <= 0

	## "Bone Shard x3, Health Potion, 24g" as the player reads it, its items
	## named from `registry` (the running game's when null).
	func describe(registry: ContentRegistry = null) -> String:
		var content := registry if registry != null else ContentRegistry.active
		var parts := PackedStringArray()
		for item_id: StringName in items:
			var item: ItemData = content.get_entry(ItemData.KIND, item_id) as ItemData if content != null else null
			var item_name := String(TranslationServer.translate(item.display_name)) if item != null else String(item_id)
			parts.append(item_name if items[item_id] <= 1 else "%s x%d" % [item_name, items[item_id]])
		if money > 0:
			parts.append(TranslationServer.translate("%dg") % money)
		return GameText.list(parts)

	## Its counts as a save keeps them: {"items": {id: count}, "money": n}.
	func to_save_data() -> Dictionary:
		var counts := {}
		for item_id: StringName in items:
			counts[String(item_id)] = items[item_id]
		return {"items": counts, "money": money}

	## What `raw` (from `to_save_data()`) holds; empty for anything else.
	static func from_save_data(raw: Variant) -> Find:
		var find := Find.new()
		if not raw is Dictionary:
			return find
		var counts: Variant = (raw as Dictionary).get("items", {})
		if counts is Dictionary:
			for raw_id: Variant in counts:
				var count := SaveValues.count((counts as Dictionary)[raw_id])
				if count > 0:
					find.items[StringName(String(raw_id))] = count
		find.money = SaveValues.count((raw as Dictionary).get("money", 0))
		return find

## What a find may hold.
@export var entries: Array[LootEntry] = []
## How many entries a find draws; fewer when fewer have come by its level.
@export_range(0, 16, 1) var picks := 1
## The money a find holds at its first level, from the least to the most.
@export_range(0, 99999, 1, "or_greater") var money_min := 0
@export_range(0, 99999, 1, "or_greater") var money_max := 0
## How much more money each level past the first adds.
@export_range(0.0, 1000.0, 0.1, "or_greater") var money_per_level := 0.0

## A find at `level`, drawn from `rolls`.
func roll(rolls: GameRandomStream, level := 0) -> Find:
	var find := Find.new()
	var open: Array[LootEntry] = []
	for entry: LootEntry in entries:
		if entry != null and entry.item_id != &"" and entry.weight > 0.0 and level >= entry.from_level:
			open.append(entry)
	for _pick: int in picks:
		if open.is_empty():
			break
		var weights := PackedFloat64Array()
		for entry: LootEntry in open:
			weights.append(entry.weight)
		var picked: LootEntry = open.pop_at(rolls.pick_weighted(weights))
		var count := rolls.randi_range(picked.min_quantity, maxi(picked.min_quantity, picked.max_quantity))
		find.items[picked.item_id] = find.items.get(picked.item_id, 0) + count
	if money_max > 0 or money_per_level > 0.0:
		var base := rolls.randi_range(money_min, maxi(money_min, money_max))
		find.money = base + rolls.round_by_chance(money_per_level * maxi(level - 1, 0))
	return find

## The ids of the items a find may hold, at any level, each once.
func get_item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: LootEntry in entries:
		if entry != null and entry.item_id != &"" and entry.weight > 0.0 and not ids.has(entry.item_id):
			ids.append(entry.item_id)
	return ids

## Adds `way` (translated already: "Found in chests in the depths") as a way
## to get each item a find may hold (`ItemSources`).
func add_ways(sources: ItemSources, way: String) -> void:
	for item_id: StringName in get_item_ids():
		sources.add(item_id, way)

## What is wrong with the table against `registry`'s items.
func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for index: int in entries.size():
		var entry := entries[index]
		if entry == null or entry.item_id == &"":
			problems.append("loot entry %d names no item" % index)
			continue
		if registry != null and registry.get_entry(ItemData.KIND, entry.item_id) == null:
			problems.append("loot entry %d gives item '%s', which does not exist" % [index, entry.item_id])
		if entry.max_quantity < entry.min_quantity:
			problems.append("loot entry %d gives at most %d, fewer than its least %d" % [index, entry.max_quantity, entry.min_quantity])
	if money_max < money_min:
		problems.append("loot money at most %d, less than its least %d" % [money_max, money_min])
	if (entries.is_empty() or picks <= 0) and money_max <= 0 and money_per_level <= 0.0:
		problems.append("loot table finds nothing")
	return problems
