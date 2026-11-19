class_name ItemInheritance
extends InheritanceRule

## Carries items of the inventory over (`Playthrough`): those with one of
## `tags`, or every item when it lists none. The new game gets as many of each
## as its inventory holds; an item its content does not have is left behind.

@export var tags: PackedStringArray = []

func _init() -> void:
	key = &"items"

func capture() -> Variant:
	var items: Dictionary = {}
	for entry: Dictionary in InventoryState.get_entries():
		var item := ItemData.find(StringName(String(entry["id"])))
		if item != null and _carries(item):
			items[String(item.id)] = int(entry["quantity"])
	return items

func apply(data: Variant) -> void:
	if not data is Dictionary:
		return
	var items: Dictionary = data
	var ids: Array = items.keys()
	ids.sort()
	for raw_id: Variant in ids:
		var item := ItemData.find(StringName(String(raw_id)))
		var quantity := SaveValues.count(items[raw_id])
		if item != null and quantity > 0 and _carries(item):
			InventoryState.add_item(item, quantity)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for tag: String in tags:
		var used := false
		for entry: Variant in registry.get_entries(ItemData.KIND):
			if entry is ItemData and (entry as ItemData).has_tag(tag):
				used = true
				break
		if not used:
			problems.append("carries items tagged '%s', which no item has" % tag)
	return problems

func _carries(item: ItemData) -> bool:
	if tags.is_empty():
		return true
	for tag: String in tags:
		if item.has_tag(tag):
			return true
	return false
