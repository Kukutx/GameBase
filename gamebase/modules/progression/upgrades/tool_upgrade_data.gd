class_name ToolUpgradeData
extends ContentEntry

@export var display_name: String
@export var source_item_id: StringName
@export var result_item_id: StringName
@export var materials: Dictionary = {}
@export_range(0, 999999, 1) var money_cost := 0
## When the upgrade is offered, as a `GameRules` query; empty: always.
@export var condition := ""

func meets_requirements(inventory: InventoryStore = InventoryState) -> bool:
	if inventory == null or source_item_id == &"" or result_item_id == &"" or money_cost < 0:
		return false
	if not inventory.has_item(source_item_id, 1):
		return false
	if PlayerState.money < money_cost:
		return false
	if not GameRules.check(condition):
		return false
	return inventory.can_apply_transaction(materials, {})
