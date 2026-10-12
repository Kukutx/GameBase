class_name WorldItemPickup
extends Node2D

signal fully_collected(item_id: StringName)
signal items_collected(item_id: StringName, collected: int, remaining: int)

@export var item: ItemData
@export_range(1, 999, 1) var quantity := 1
## Makes what is left of the pickup persist in `WorldState`: a pickup taken in
## part keeps the rest, and one taken whole stays gone.
@export var persistent_id: StringName
@export var counts_as_forage := true

@onready var interactable: Interactable = $Interactable
@onready var label: Label = $Label

var _collection_busy := false

func _ready() -> void:
	if persistent_id != &"":
		var left: Variant = SaveValues.whole_number(WorldState.get_value(_left_key()))
		if left != null and int(left) <= 0:
			queue_free()
			return
		if left != null:
			quantity = mini(int(left), quantity)
	interactable.interacted.connect(_on_interacted)
	_refresh_label()

func _on_interacted(actor: Node) -> void:
	if _collection_busy:
		return
	_collection_busy = true
	_collect(actor)
	if not is_queued_for_deletion():
		_collection_busy = false

func _collect(_actor: Node) -> void:
	if item == null:
		return
	var original_quantity := quantity
	var remaining := InventoryState.add_item(item, quantity)
	var collected := original_quantity - remaining
	if collected > 0:
		if persistent_id != &"":
			WorldState.set_value(_left_key(), remaining)
		if counts_as_forage:
			ItemsEvents.item_foraged.emit(item.id, collected)
		items_collected.emit(item.id, collected, remaining)
	if remaining <= 0:
		fully_collected.emit(item.id)
		queue_free()
		return
	quantity = remaining
	_refresh_label()

func set_quantity(value: int) -> void:
	quantity = maxi(value, 1)
	_refresh_label()

func _refresh_label() -> void:
	if label == null:
		return
	if item == null:
		label.text = tr("Item")
		return
	var name_text := item.display_name if not item.display_name.is_empty() else String(item.id)
	label.text = "%s x%d" % [tr(name_text), quantity]
	interactable.set_prompt("Pick up %s", [name_text])

# What is left of the pickup once the player took some: 0 once taken whole.
func _left_key() -> StringName:
	return StringName("pickup:%s" % String(persistent_id))

## The world state the node saves, for `ContentRegistry`'s check that no two
## nodes share it.
func get_persistent_keys() -> PackedStringArray:
	return PackedStringArray([String(_left_key())]) if persistent_id != &"" else PackedStringArray()
