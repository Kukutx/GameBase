class_name ItemsSettings
extends ModuleSettings

## What a game sets for the items module (`GameDefinition.module_settings`):
## what a new game starts with.

## Money a new game starts with (`Wallet`).
@export_range(0, 999999) var start_money := 0
## Items a new game starts with, as item id → amount.
@export var start_items: Dictionary[StringName, int] = {}
## The hotbar of a new game, slot by slot (item ids; empty for a free slot).
@export var start_hotbar: Array[StringName] = []

## The running game's items settings.
static func current() -> ItemsSettings:
	return GameDefinition.current().get_settings(ItemsSettings) as ItemsSettings

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for item_id: StringName in start_items:
		if not registry.has_entry(ItemData.KIND, item_id):
			problems.append("start item '%s' is no item" % item_id)
		elif start_items[item_id] <= 0:
			problems.append("start item '%s' has no amount" % item_id)
	for item_id: StringName in start_hotbar:
		if item_id != &"" and not registry.has_entry(ItemData.KIND, item_id):
			problems.append("start hotbar item '%s' is no item" % item_id)
	return problems
