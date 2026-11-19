class_name ProcessingRecipeData
extends ContentEntry

const KIND := &"processing_recipe"

@export var display_name: String
@export var inputs: Dictionary = {}
@export var output_item_id: StringName
@export_range(1, 99, 1) var output_quantity := 1
@export_range(1, 10080, 1) var process_minutes := 60
## When the recipe can start, as a `GameRules` query; empty: always.
@export var condition := ""

## The processing recipe with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> ProcessingRecipeData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as ProcessingRecipeData

## The running game's processing recipes, sorted by id.
static func find_all() -> Array[ProcessingRecipeData]:
	var result: Array[ProcessingRecipeData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func can_start(inventory: InventoryStore = InventoryState) -> bool:
	if inventory == null or output_item_id == &"" or output_quantity <= 0 or process_minutes <= 0:
		return false
	if not GameRules.check(condition):
		return false
	# Strict transaction validation rejects malformed input quantities instead of
	# coercing them into a free processing job.
	return inventory.can_apply_transaction(inputs, {})

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if inputs.is_empty():
		problems.append("has no inputs")
	problems.append_array(ItemData.find_amount_problems(inputs, registry, "requires", "input quantity"))
	if not registry.has_entry(ItemData.KIND, output_item_id):
		problems.append("outputs unknown item '%s'" % output_item_id)
	if output_quantity <= 0:
		problems.append("has invalid output quantity")
	if process_minutes <= 0:
		problems.append("has invalid process duration")
	return problems
