class_name CraftingMenu
extends CanvasLayer

@onready var title_label: Label = $Panel/VBox/Title
@onready var recipes_container: VBoxContainer = $Panel/VBox/Recipes
@onready var close_button: Button = $Panel/VBox/Close

var current_category: RecipeData.Category = RecipeData.Category.CRAFTING
var current_station_name := "Crafting"

func _ready() -> void:
	add_to_group("crafting_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	InventoryState.changed.connect(_refresh_if_visible)
	GameSettings.locale_changed.connect(_on_locale_changed)

func open(category: RecipeData.Category = RecipeData.Category.CRAFTING, station_name: String = "Crafting") -> void:
	current_category = category
	current_station_name = station_name
	visible = true
	get_tree().paused = true
	_rebuild()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	title_label.text = tr(current_station_name)
	for child: Node in recipes_container.get_children():
		child.queue_free()
	var first_button: Button
	for recipe: RecipeData in CraftingState.get_all_recipes():
		if recipe.category != current_category:
			continue
		var button := Button.new()
		button.text = _recipe_text(recipe)
		button.disabled = not CraftingState.can_craft(recipe)
		button.pressed.connect(_craft.bind(recipe.id))
		recipes_container.add_child(button)
		if first_button == null and not button.disabled:
			first_button = button
	if first_button != null:
		first_button.grab_focus()
	else:
		close_button.grab_focus()

func _recipe_text(recipe: RecipeData) -> String:
	var parts: PackedStringArray = []
	for raw_id: Variant in recipe.ingredients.keys():
		var item := ItemData.find(StringName(String(raw_id)))
		var label := tr(item.display_name) if item != null else String(raw_id)
		parts.append("%s x%d" % [label, int(recipe.ingredients[raw_id])])
	return "%s  (%s)" % [tr(recipe.display_name), ", ".join(parts)]

func _craft(recipe_id: StringName) -> void:
	CraftingState.craft(recipe_id)
	_rebuild()

func _on_locale_changed(_locale: String) -> void:
	_refresh_if_visible()

func _refresh_if_visible() -> void:
	if visible:
		_rebuild()
