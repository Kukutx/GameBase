class_name ShopStand
extends Node2D

## A stand that opens `shop`; each placed stand names the game's shop. Its
## sign shows the shop's name unless the placed stand sets a shorter one.
@export var shop: ShopData
@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	if shop != null:
		if label.text.is_empty():
			label.text = shop.display_name
		interactable.set_prompt("Shop: %s", [shop.display_name])

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("shop_menu") as ShopMenu
	if menu == null:
		GameEvents.toast("Shop UI is unavailable")
		return
	menu.open(shop)
