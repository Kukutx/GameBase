class_name ProcessingRecipeData
extends ContentEntry

@export var display_name: String
@export var inputs: Dictionary = {}
@export var output_item_id: StringName
@export_range(1, 99, 1) var output_quantity := 1
@export_range(1, 10080, 1) var process_minutes := 60
@export var required_skill: StringName
@export_range(1, 10, 1) var required_level := 1

func can_start(inventory: InventoryStore = InventoryState) -> bool:
	if inventory == null or output_item_id == &"" or output_quantity <= 0 or process_minutes <= 0:
		return false
	if required_skill != &"" and Skills.get_level(required_skill) < required_level:
		return false
	# Strict transaction validation rejects malformed input quantities instead of
	# coercing them into a free processing job.
	return inventory.can_apply_transaction(inputs, {})
