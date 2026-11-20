class_name GameCraftingService
extends Node

## Crafting items from recipes (`RecipeData`): a recipe can be crafted when its
## condition holds and the player carries its ingredients, and crafting it
## swaps the ingredients for the result in the inventory (`InventoryState`) in
## one step.
##
## When the result does not fit, nothing changes and a toast tells the player
## why. A placeable result also gets a `Hotbar` slot when one is free. A recipe
## crafts as many times as asked while it can (`craft_times()`,
## `get_max_crafts()`). The service keeps no state and saves nothing; `crafted`
## announces each craft.

signal crafted(recipe_id: StringName, output_item_id: StringName, quantity: int)

var _craft_busy := false

func get_recipe(recipe_id: StringName) -> RecipeData:
	return RecipeData.find(recipe_id)

func get_all_recipes() -> Array[RecipeData]:
	return RecipeData.find_all()

func can_craft(recipe: RecipeData) -> bool:
	if recipe == null or ItemData.find(recipe.output_item_id) == null:
		return false
	if not GameRules.check(recipe.condition):
		return false
	# InventoryStore owns strict transaction quantity validation. Malformed
	# content must fail closed here rather than becoming a free craft.
	return InventoryState.can_apply_transaction(recipe.ingredients, {})

## How many times the player could craft `recipe` with the ingredients they
## carry, 0 while it cannot be crafted; the room for what it makes is not
## counted, so crafting may stop sooner.
func get_max_crafts(recipe: RecipeData) -> int:
	if not can_craft(recipe):
		return 0
	var most := -1
	for raw_id: Variant in recipe.ingredients:
		var needed := int(recipe.ingredients[raw_id])
		if needed > 0:
			var times := InventoryState.get_quantity(StringName(String(raw_id))) / needed
			most = times if most < 0 else mini(most, times)
	# A recipe of nothing crafts once a press.
	return maxi(most, 1)

func craft(recipe_id: StringName) -> bool:
	return craft_times(recipe_id, 1) == 1

## Crafts `recipe_id` up to `times` times, while it can be; how many times it
## was, told in one toast.
func craft_times(recipe_id: StringName, times: int) -> int:
	if _craft_busy or times <= 0:
		return 0
	_craft_busy = true
	var count := 0
	while count < times and _craft_internal(recipe_id, count == 0):
		count += 1
	_craft_busy = false
	var recipe := get_recipe(recipe_id)
	if count == 1:
		GameEvents.toastf("Crafted %s", [recipe.display_name])
	elif count > 1:
		GameEvents.toastf("Crafted %s x%d", [recipe.display_name, count])
	return count

# Crafts the recipe once; `speak`, a toast tells why it cannot.
func _craft_internal(recipe_id: StringName, speak: bool) -> bool:
	var recipe := get_recipe(recipe_id)
	if recipe == null or not can_craft(recipe):
		if speak:
			GameEvents.toast("Missing materials or requirements")
		return false
	var output := ItemData.find(recipe.output_item_id)
	if output == null:
		return false

	# Ingredients can occupy the slots needed by the result. Apply removals and
	# output as one inventory transaction so listeners only observe the final
	# inventory and no partial item_added/item_removed side effects can escape.
	var additions := {String(output.id): recipe.output_quantity}
	if not InventoryState.apply_transaction_atomic(recipe.ingredients, additions):
		if speak:
			GameEvents.toast("Inventory is full or materials changed")
		return false
	if output.is_placeable():
		Hotbar.ensure_item(output.id)
	crafted.emit(recipe.id, recipe.output_item_id, recipe.output_quantity)
	return true
