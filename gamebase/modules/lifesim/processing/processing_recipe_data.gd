class_name ProcessingRecipeData
extends ContentEntry

@export var display_name: String
@export var inputs: Dictionary = {}
@export var output_item_id: StringName
@export_range(1, 99, 1) var output_quantity := 1
@export_range(1, 10080, 1) var process_minutes := 60
## When the recipe can start, as a `GameRules` query; empty: always.
@export var condition := ""

func can_start(inventory: InventoryStore = InventoryState) -> bool:
	if inventory == null or output_item_id == &"" or output_quantity <= 0 or process_minutes <= 0:
		return false
	if not GameRules.check(condition):
		return false
	# Strict transaction validation rejects malformed input quantities instead of
	# coercing them into a free processing job.
	return inventory.can_apply_transaction(inputs, {})
