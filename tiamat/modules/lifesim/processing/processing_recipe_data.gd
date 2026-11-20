class_name ProcessingRecipeData
extends ContentEntry

## What a machine makes over time (`ProcessingStation`, which lists the
## recipes it runs): it takes `inputs`, and `process_minutes` of the game's
## clock later gives `output_quantity` of its output, kept in the station
## until the player collects it.

const KIND := &"processing_recipe"

## The name the player reads.
@export var display_name: String
## What it takes, as item id -> count.
@export var inputs: Dictionary = {}
## The item (`ItemData`) it makes, and how many.
@export var output_item_id: StringName
@export_range(1, 99, 1) var output_quantity := 1
## How long it takes, in minutes of the game's clock.
@export_range(1, 10080, 1, "suffix:min") var process_minutes := 60
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

## Whether it takes `item_id` among its inputs.
func takes(item_id: StringName) -> bool:
	if item_id == &"":
		return false
	for raw_id: Variant in inputs:
		if StringName(String(raw_id)) == item_id:
			return true
	return false

## What starting it takes, in words the player reads: while its condition does
## not hold, what that asks ("Mining Lv7", `GameRules.describe()`), else its
## inputs ("Iron Ore x3 and Wood").
func describe_needs() -> String:
	if not condition.is_empty() and not GameRules.check(condition):
		var words := GameRules.describe(condition)
		if not words.is_empty():
			return GameText.list(words)
	return ItemSources.describe_amounts(ContentRegistry.active, inputs)

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
