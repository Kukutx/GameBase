class_name CraftingMenu
extends MenuLayer

## A station's recipes of one category (crafting, cooking), each a button that
## crafts it as many times as the amount the player picks (`amounts`: one,
## five, as many as they can), telling what it takes and, while it cannot be
## made, what it needs and where to get it. Under the list it tells what the
## recipe whose button has the focus makes (`ItemData.describe()`).

## The amounts one press crafts, in the order the amount button steps through
## them, the first as the menu opens; 0 is as many times as the ingredients
## carried allow (`GameCraftingService.get_max_crafts()`). One amount hides the
## button.
@export var amounts: PackedInt32Array = PackedInt32Array([1, 5, 0])

@onready var title_label: Label = $Panel/VBox/Title
@onready var amount_button: Button = $Panel/VBox/Amount
@onready var recipes_container: VBoxContainer = $Panel/VBox/Scroll/Recipes
@onready var about_label: Label = $Panel/VBox/About
@onready var close_button: Button = $Panel/VBox/Close

var current_category: RecipeData.Category = RecipeData.Category.CRAFTING
var current_station_name := "Crafting"
var _amount_index := 0

func _init() -> void:
	super(&"crafting_menu")

func _ready() -> void:
	close_button.pressed.connect(close)
	amount_button.pressed.connect(_next_amount)
	InventoryState.changed.connect(_refresh_if_visible)
	GameSettings.locale_changed.connect(_on_locale_changed)

func open(category: RecipeData.Category = RecipeData.Category.CRAFTING, station_name: String = "Crafting") -> void:
	current_category = category
	current_station_name = station_name
	_amount_index = 0
	show_menu()
	_rebuild(false)

## How many times one press crafts now; 0, as many as the player can.
func get_amount() -> int:
	return maxi(amounts[_amount_index], 0) if _amount_index < amounts.size() else 1

## Builds the recipes' buttons; `keep_focus`, on the recipe whose button had it
## (`MenuLayer.focus_kept()`), so crafting one leaves the player on it.
func _rebuild(keep_focus := true) -> void:
	var kept: Variant = MenuLayer.focused_key(self) if keep_focus else null
	title_label.text = tr(current_station_name)
	amount_button.visible = amounts.size() > 1
	amount_button.text = tr("Amount: %d") % get_amount() if get_amount() > 0 else tr("Amount: All")
	about_label.text = ""
	for child: Node in recipes_container.get_children():
		child.queue_free()
	var buttons: Array[Button] = []
	# Where to get what a recipe lacks, found once for every recipe.
	var sources := ItemSources.gather()
	for recipe: RecipeData in CraftingState.get_all_recipes():
		if recipe.category != current_category:
			continue
		var button := MenuLayer.list_button()
		button.text = _recipe_text(recipe, sources)
		button.disabled = not CraftingState.can_craft(recipe)
		button.set_meta(MenuLayer.FOCUS_KEY, recipe.id)
		button.pressed.connect(_craft.bind(recipe.id))
		button.focus_entered.connect(_tell_about.bind(recipe))
		recipes_container.add_child(button)
		buttons.append(button)
	MenuLayer.focus_kept(buttons, kept, close_button)

# A recipe's button: what it makes and takes, for as many times as one press
# crafts it, then what it lacks.
func _recipe_text(recipe: RecipeData, sources: ItemSources) -> String:
	var times := _times(recipe)
	var parts: PackedStringArray = []
	for raw_id: Variant in recipe.ingredients.keys():
		var item := ItemData.find(StringName(String(raw_id)))
		var label := tr(item.display_name) if item != null else String(raw_id)
		parts.append("%s x%d" % [label, int(recipe.ingredients[raw_id]) * times])
	var title := tr(recipe.display_name) if times == 1 else "%s x%d" % [tr(recipe.display_name), times]
	var lines := PackedStringArray(["%s  (%s)" % [title, GameText.list(parts)]])
	# A recipe the player cannot craft yet says what it still needs.
	var needs := GameRules.describe(recipe.condition) if not GameRules.check(recipe.condition) else PackedStringArray()
	if not needs.is_empty():
		lines.append(tr("Needs: %s") % GameText.list(needs))
	# And where to get each ingredient the player lacks.
	for raw_id: Variant in recipe.ingredients.keys():
		var item_id := StringName(String(raw_id))
		var ways := sources.get_ways(item_id)
		if InventoryState.get_quantity(item_id) < int(recipe.ingredients[raw_id]) and not ways.is_empty():
			var item := ItemData.find(item_id)
			lines.append("%s: %s" % [tr(item.display_name) if item != null else String(raw_id), ways[0]])
	return "\n".join(lines)

# How many times one press crafts `recipe`: the amount picked, or as many as
# the player can (at least one, for its label).
func _times(recipe: RecipeData) -> int:
	return get_amount() if get_amount() > 0 else maxi(CraftingState.get_max_crafts(recipe), 1)

func _craft(recipe_id: StringName) -> void:
	CraftingState.craft_times(recipe_id, _times(CraftingState.get_recipe(recipe_id)))
	_rebuild()

func _tell_about(recipe: RecipeData) -> void:
	var item := ItemData.find(recipe.output_item_id)
	about_label.text = item.describe() if item != null else ""

# Steps to the next amount, telling each recipe's button anew in place, so the
# focus stays on the amount.
func _next_amount() -> void:
	if amounts.size() < 2:
		return
	_amount_index = (_amount_index + 1) % amounts.size()
	amount_button.text = tr("Amount: %d") % get_amount() if get_amount() > 0 else tr("Amount: All")
	var sources := ItemSources.gather()
	for child: Node in recipes_container.get_children():
		var recipe := CraftingState.get_recipe(StringName(String(child.get_meta(MenuLayer.FOCUS_KEY, ""))))
		if recipe != null:
			(child as Button).text = _recipe_text(recipe, sources)

func _on_locale_changed(_locale: String) -> void:
	_refresh_if_visible()

func _refresh_if_visible() -> void:
	if visible:
		_rebuild()
