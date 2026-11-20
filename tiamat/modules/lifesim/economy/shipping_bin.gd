class_name ShippingBin
extends Node2D

## The bin the player ships items in, paid for overnight (`ShippingService`).
## It opens the game's `ShippingMenu` where the HUD has one, to ship any item
## carried, so many at a press; without one it ships one of the item in hand.

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	ShippingState.shipment_changed.connect(_refresh)
	ShippingState.payout_completed.connect(_on_payout)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	var menu := get_tree().get_first_node_in_group(&"shipping_menu") as ShippingMenu
	if menu != null:
		menu.open()
		return
	var item_id := Hotbar.get_selected_item_id()
	if item_id == &"":
		GameEvents.toast("Select an item to ship")
		return
	ShippingState.ship_item(item_id, 1)

func _on_payout(_amount: int) -> void:
	_refresh()

func _refresh() -> void:
	if label == null or interactable == null:
		return
	var total := ShippingState.get_pending_total()
	label.text = tr("Shipping\n%dg pending") % total if total > 0 else tr("Shipping\nEmpty")
	var has_menu := get_tree() != null and get_tree().get_first_node_in_group(&"shipping_menu") != null
	interactable.prompt_text = "Ship items" if has_menu else "Ship selected item"
