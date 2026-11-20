class_name RecipeData
extends ContentEntry

## What the player makes from what they carry: `ingredients` swapped for the
## `output_item_id` in one step (`CraftingService`), at a station of its
## `category` (`CraftingStation`), once its `condition` holds.

## The stations that make it: a workbench crafts, a kitchen cooks.
enum Category {
	CRAFTING,
	COOKING,
}

const KIND := &"recipe"

## The name the player reads.
@export var display_name: String
## The stations that make it (`CraftingStation`): a workbench or a kitchen.
@export var category: Category = Category.CRAFTING
## What it takes, as item id -> count.
@export var ingredients: Dictionary = {}
## The item (`ItemData`) it makes.
@export var output_item_id: StringName
## How many of it one craft makes.
@export_range(1, 99, 1) var output_quantity := 1
## When the recipe can be crafted, as a `GameRules` query; empty: always.
@export var condition := ""

## The recipe with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> RecipeData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as RecipeData

## The running game's recipes, sorted by id.
static func find_all() -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has an empty display name")
	if not Category.values().has(category):
		problems.append("has invalid category %d" % category)
	if ingredients.is_empty():
		problems.append("has no ingredients")
	problems.append_array(ItemData.find_amount_problems(ingredients, registry, "requires", "ingredient quantity"))
	if not registry.has_entry(ItemData.KIND, output_item_id):
		problems.append("outputs unknown item '%s'" % output_item_id)
	if output_quantity <= 0:
		problems.append("has invalid output quantity %d" % output_quantity)
	return problems
