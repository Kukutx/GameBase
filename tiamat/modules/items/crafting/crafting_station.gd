class_name CraftingStation
extends Node2D

@export var category: RecipeData.Category = RecipeData.Category.CRAFTING
@export var station_name := "Workbench"

@onready var interactable: Interactable = $Interactable
@onready var label: Label = get_node_or_null("Label") as Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	GameSettings.locale_changed.connect(_on_locale_changed)
	interactable.set_prompt("Use %s", [station_name])
	_refresh_label()

func _on_locale_changed(_locale: String) -> void:
	_refresh_label()

func _refresh_label() -> void:
	if label != null:
		label.text = tr(station_name)

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("crafting_menu") as CraftingMenu
	if menu == null:
		GameEvents.toast("Crafting UI is unavailable")
		return
	menu.open(category, station_name)
