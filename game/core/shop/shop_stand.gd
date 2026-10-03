class_name ShopStand
extends Node2D

@export var shop: ShopData
@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	if shop != null:
		interactable.set_prompt("Shop: %s", [shop.display_name])

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group("shop_menu") as ShopMenu
	if menu == null:
		GameEvents.toast("Shop UI is unavailable")
		return
	menu.open(shop)
