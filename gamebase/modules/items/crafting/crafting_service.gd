class_name GameCraftingService
extends Node

signal crafted(recipe_id: StringName, output_item_id: StringName, quantity: int)

var _craft_busy := false

func get_recipe(recipe_id: StringName) -> RecipeData:
	return ContentDB.get_recipe(recipe_id)

func get_all_recipes() -> Array[RecipeData]:
	return ContentDB.get_all_recipes()

func can_craft(recipe: RecipeData) -> bool:
	if recipe == null or ItemCatalog.get_item(recipe.output_item_id) == null:
		return false
	if recipe.required_skill != &"" and Skills.get_level(recipe.required_skill) < recipe.required_level:
		return false
	# InventoryStore owns strict transaction quantity validation. Malformed
	# content must fail closed here rather than becoming a free craft.
	return InventoryState.can_apply_transaction(recipe.ingredients, {})

func craft(recipe_id: StringName) -> bool:
	if _craft_busy:
		return false
	_craft_busy = true
	var result := _craft_internal(recipe_id)
	_craft_busy = false
	return result

func _craft_internal(recipe_id: StringName) -> bool:
	var recipe := get_recipe(recipe_id)
	if recipe == null or not can_craft(recipe):
		GameEvents.toast("Missing materials or skill level")
		return false
	var output := ItemCatalog.get_item(recipe.output_item_id)
	if output == null:
		return false

	# Ingredients can occupy the slots needed by the result. Apply removals and
	# output as one inventory transaction so listeners only observe the final
	# inventory and no partial item_added/item_removed side effects can escape.
	var additions := {String(output.id): recipe.output_quantity}
	if not InventoryState.apply_transaction_atomic(recipe.ingredients, additions):
		GameEvents.toast("Inventory is full or materials changed")
		return false
	if output.is_placeable():
		Hotbar.ensure_item(output.id)
	crafted.emit(recipe.id, recipe.output_item_id, recipe.output_quantity)
	GameEvents.toastf("Crafted %s", [recipe.display_name])
	return true
