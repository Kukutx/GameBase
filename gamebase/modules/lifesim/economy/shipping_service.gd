class_name ShippingService
extends Node

## The shipping bin: items the player ships leave the inventory at once and are
## paid for overnight, at their `sell_price`, when the world clock's day
## changes. It holds what waits in the bin and the last day it paid out.
##
## Tools, quest items and items without a sell price cannot be shipped. The bin
## and its day marker are saved with the game and restored before the clock, so
## loading a save never pays a day twice; a new game starts with an empty bin.
## `item_shipped` fires for each shipment and `payout_completed` for each
## night's pay.

signal shipment_changed
signal item_shipped(item_id: StringName, quantity: int, value: int)
signal payout_completed(amount: int)

var _pending: Dictionary = {}
var _last_day_seen := 1
var _shipping_busy := false

func _ready() -> void:
	WorldClock.day_changed.connect(_on_day_changed)
	_last_day_seen = WorldClock.day

func ship_item(item_id: StringName, quantity: int = 1) -> bool:
	if _shipping_busy:
		return false
	_shipping_busy = true
	var result := _ship_item_internal(item_id, quantity)
	_shipping_busy = false
	return result

func _ship_item_internal(item_id: StringName, quantity: int) -> bool:
	if item_id == &"" or quantity <= 0:
		return false
	var item := ItemData.find(item_id)
	if item == null or item.sell_price <= 0 or item.kind == ItemData.Kind.TOOL or item.kind == ItemData.Kind.QUEST:
		GameEvents.toast("That item cannot be shipped")
		return false
	if not InventoryState.remove_item(item_id, quantity):
		GameEvents.toastf("You do not have enough %s", [item.display_name])
		return false
	var key := String(item_id)
	var entry: Dictionary = _pending.get(key, {"quantity": 0, "value": 0})
	entry["quantity"] = int(entry.get("quantity", 0)) + quantity
	entry["value"] = int(entry.get("value", 0)) + item.sell_price * quantity
	_pending[key] = entry
	shipment_changed.emit()
	item_shipped.emit(item_id, quantity, item.sell_price * quantity)
	GameEvents.toastf("Shipped %s x%d", [item.display_name, quantity])
	return true

func get_pending_total() -> int:
	var total := 0
	for raw: Variant in _pending.values():
		if raw is Dictionary:
			total += int(raw.get("value", 0))
	return total

func get_pending_quantity(item_id: StringName) -> int:
	var entry: Dictionary = _pending.get(String(item_id), {})
	return int(entry.get("quantity", 0))

func get_summary() -> String:
	var total := get_pending_total()
	if total <= 0:
		return "Shipping bin: empty"
	var count := 0
	for raw: Variant in _pending.values():
		if raw is Dictionary:
			count += int(raw.get("quantity", 0))
	return "Shipping bin: %d item%s · %dg overnight" % [count, "" if count == 1 else "s", total]

func payout_pending() -> int:
	var amount := get_pending_total()
	if amount <= 0:
		return 0
	_pending.clear()
	PlayerState.add_money(amount)
	shipment_changed.emit()
	payout_completed.emit(amount)
	GameEvents.toastf("Overnight shipping earned %dg", [amount])
	return amount

func reset_new_game() -> void:
	_pending.clear()
	# The day the new game starts on: the clock is reset after this step.
	_last_day_seen = GameDefinition.current().start_day
	shipment_changed.emit()

func to_save_data() -> Dictionary:
	return {
		"pending": _pending.duplicate(true),
		"last_day_seen": _last_day_seen,
	}

func load_save_data(data: Dictionary) -> void:
	_pending.clear()
	var raw_pending: Variant = data.get("pending", {})
	if raw_pending is Dictionary:
		for raw_key: Variant in raw_pending.keys():
			var raw_entry: Variant = raw_pending[raw_key]
			if not raw_entry is Dictionary:
				continue
			var entry: Dictionary = raw_entry
			var quantity := SaveValues.count(entry.get("quantity", 0))
			var value := SaveValues.count(entry.get("value", 0))
			if quantity <= 0 or value <= 0:
				continue
			_pending[String(raw_key)] = {"quantity": quantity, "value": value}
	_last_day_seen = maxi(SaveValues.whole_number_or(data.get("last_day_seen", WorldClock.day), WorldClock.day), 1)
	shipment_changed.emit()

func _on_day_changed(day: int) -> void:
	if day <= _last_day_seen:
		return
	# Commit the observed day before payout. money_changed listeners can advance
	# the clock synchronously; an outer callback must never overwrite a newer
	# nested day marker when it resumes.
	_last_day_seen = day
	payout_pending()
