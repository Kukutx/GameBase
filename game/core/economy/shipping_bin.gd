class_name ShippingBin
extends Node2D

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	ShippingState.shipment_changed.connect(_refresh)
	ShippingState.payout_completed.connect(_on_payout)
	_refresh()

func _on_interacted(_actor: Node) -> void:
	var item_id := PlayerState.get_selected_item_id()
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
	interactable.prompt_text = "Ship selected item"
