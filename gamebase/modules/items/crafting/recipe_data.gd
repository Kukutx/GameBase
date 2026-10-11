class_name RecipeData
extends ContentEntry

enum Category {
	CRAFTING,
	COOKING,
}

@export var display_name: String
@export var category: Category = Category.CRAFTING
@export var ingredients: Dictionary = {}
@export var output_item_id: StringName
@export_range(1, 99, 1) var output_quantity := 1
## When the recipe can be crafted, as a `GameRules` query; empty: always.
@export var condition := ""
