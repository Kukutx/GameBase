class_name InventoryStore
extends Node

## A slot-limited inventory.
##
## The store keeps one quantity per item; the stacks that fill slots are derived
## from each item's `max_stack`. Save data is `{item_id: quantity}` and loads
## only items that are current content.

signal changed
signal item_added(item_id: StringName, quantity: int)
signal item_removed(item_id: StringName, quantity: int)

@export_range(1, 200, 1) var max_slots := 24

## item id (String) -> quantity.
var _items: Dictionary = {}
## item id (String) -> ItemData of every held item, so an item added directly
## (not from the catalog) keeps its stack size and name.
var _definitions: Dictionary = {}

func add_item(item: ItemData, quantity: int = 1) -> int:
	if item == null or item.id == &"" or quantity <= 0:
		return quantity
	var accepted := mini(quantity, get_add_capacity(item))
	if accepted <= 0:
		return quantity
	_put(_items, _definitions, item, accepted)
	changed.emit()
	item_added.emit(item.id, accepted)
	return quantity - accepted

func add_item_by_id(item_id: StringName, quantity: int = 1) -> int:
	var item := ItemData.find(item_id)
	return add_item(item, quantity) if item != null else quantity

func get_add_capacity(item: ItemData) -> int:
	if item == null or item.id == &"":
		return 0
	return _capacity_for(_items, _definitions, item)

func can_add_item(item: ItemData, quantity: int = 1) -> bool:
	return quantity <= 0 or (item != null and get_add_capacity(item) >= quantity)

func can_add_items_by_id(items: Dictionary) -> bool:
	return can_apply_transaction({}, items)

## Adds every item in `items` (id -> int quantity) or nothing when any of them
## does not fit or is not current content.
func add_items_atomic(items: Dictionary) -> bool:
	return apply_transaction_atomic({}, items)

## Removes `removals` and adds `additions` (both id -> int quantity) as one
## step: when any part fails nothing changes and no signal is emitted.
## Listeners of the emitted signals already see the final state.
func apply_transaction_atomic(removals: Dictionary, additions: Dictionary) -> bool:
	var plan := _plan_transaction(removals, additions)
	if plan.is_empty():
		return false
	var removed: Array = plan["removed"]
	var added: Array = plan["added"]
	if removed.is_empty() and added.is_empty():
		return true
	_items = plan["items"]
	_definitions = plan["definitions"]
	changed.emit()
	for event: Array in removed:
		item_removed.emit(event[0] as StringName, int(event[1]))
	for event: Array in added:
		item_added.emit(event[0] as StringName, int(event[1]))
	return true

func can_apply_transaction(removals: Dictionary, additions: Dictionary) -> bool:
	return not _plan_transaction(removals, additions).is_empty()

func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if not _take(_items, _definitions, String(item_id), quantity):
		return false
	changed.emit()
	item_removed.emit(item_id, quantity)
	return true

func has_item(item_id: StringName, quantity: int = 1) -> bool:
	return quantity <= 0 or get_quantity(item_id) >= quantity

## Whether the inventory holds a tool that performs `action` (an ItemData.ACTION_ constant
## or an action of the game's own).
func has_tool(action: StringName) -> bool:
	for key: String in _items.keys():
		var item: ItemData = _definitions[key]
		if item.is_tool() and item.tool_action == action:
			return true
	return false

func get_quantity(item_id: StringName) -> int:
	return int(_items.get(String(item_id), 0))

func get_used_slots() -> int:
	return _used_slots(_items, _definitions)

func get_free_slots() -> int:
	return maxi(max_slots - get_used_slots(), 0)

func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in _items.keys():
		var item: ItemData = _definitions[key]
		var quantity := int(_items[key])
		var max_stack := maxi(item.max_stack, 1)
		result.append({
			"id": key,
			"display_name": item.display_name if not item.display_name.is_empty() else key,
			"quantity": quantity,
			"max_stack": max_stack,
			"slots": _stack_count(quantity, max_stack),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["display_name"]) < String(b["display_name"]))
	return result

func get_slot_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in get_entries():
		var remaining := int(entry["quantity"])
		var stack_size := int(entry["max_stack"])
		while remaining > 0:
			var stack_quantity := mini(remaining, stack_size)
			result.append({
				"id": entry["id"],
				"display_name": entry["display_name"],
				"quantity": stack_quantity,
				"max_stack": stack_size,
			})
			remaining -= stack_quantity
	return result

func get_summary(max_entries: int = 4) -> String:
	var entries := get_entries()
	if entries.is_empty():
		return tr("Inventory: empty (%d/%d slots)") % [get_used_slots(), max_slots]
	var parts: PackedStringArray = []
	for index in range(mini(entries.size(), maxi(max_entries, 0))):
		var entry: Dictionary = entries[index]
		parts.append("%s x%d" % [tr(String(entry["display_name"])), entry["quantity"]])
	if entries.size() > max_entries:
		parts.append(tr("+%d more") % (entries.size() - max_entries))
	return tr("Inventory %d/%d: %s") % [get_used_slots(), max_slots, ", ".join(parts)]

func clear() -> void:
	if _items.is_empty():
		return
	_items.clear()
	_definitions.clear()
	changed.emit()

func to_save_data() -> Dictionary:
	return _items.duplicate()

## Loads `{item_id: quantity}`. Entries that are not current items or not
## positive numbers are dropped.
func load_save_data(data: Dictionary) -> void:
	_items.clear()
	_definitions.clear()
	for raw_key: Variant in data.keys():
		var raw_quantity: Variant = data[raw_key]
		if typeof(raw_quantity) != TYPE_INT and typeof(raw_quantity) != TYPE_FLOAT:
			continue
		var item := ItemData.find(StringName(String(raw_key)))
		var quantity := int(raw_quantity)
		if item != null and quantity > 0:
			_put(_items, _definitions, item, quantity)
	changed.emit()

## The state after a transaction, as {"items", "definitions", "removed",
## "added"} with removed/added as [id, quantity] pairs, or {} when it fails.
func _plan_transaction(removals: Dictionary, additions: Dictionary) -> Dictionary:
	var items := _items.duplicate()
	var definitions := _definitions.duplicate()
	var removed: Array = []
	var added: Array = []
	for raw_id: Variant in removals.keys():
		var quantity := _strict_transaction_quantity(removals[raw_id])
		if quantity < 0:
			return {}
		if quantity == 0:
			continue
		var item_id := StringName(String(raw_id))
		if not _take(items, definitions, String(item_id), quantity):
			return {}
		removed.append([item_id, quantity])
	for raw_id: Variant in additions.keys():
		var quantity := _strict_transaction_quantity(additions[raw_id])
		if quantity < 0:
			return {}
		if quantity == 0:
			continue
		var item := ItemData.find(StringName(String(raw_id)))
		if item == null or _capacity_for(items, definitions, item) < quantity:
			return {}
		_put(items, definitions, item, quantity)
		added.append([item.id, quantity])
	return {"items": items, "definitions": definitions, "removed": removed, "added": added}

func _capacity_for(items: Dictionary, definitions: Dictionary, item: ItemData) -> int:
	var current := int(items.get(String(item.id), 0))
	var stack_size := maxi(item.max_stack, 1)
	var other_slots := _used_slots(items, definitions) - _stack_count(current, stack_size)
	return maxi(maxi(max_slots - other_slots, 0) * stack_size - current, 0)

static func _used_slots(items: Dictionary, definitions: Dictionary) -> int:
	var used := 0
	for key: String in items.keys():
		used += _stack_count(int(items[key]), (definitions[key] as ItemData).max_stack)
	return used

static func _put(items: Dictionary, definitions: Dictionary, item: ItemData, quantity: int) -> void:
	var key := String(item.id)
	items[key] = int(items.get(key, 0)) + quantity
	definitions[key] = item

static func _take(items: Dictionary, definitions: Dictionary, key: String, quantity: int) -> bool:
	var current := int(items.get(key, 0))
	if quantity <= 0 or current < quantity:
		return false
	if current == quantity:
		items.erase(key)
		definitions.erase(key)
	else:
		items[key] = current - quantity
	return true

static func _strict_transaction_quantity(value: Variant) -> int:
	if typeof(value) != TYPE_INT:
		return -1
	return maxi(int(value), 0)

static func _stack_count(quantity: int, stack_size: int) -> int:
	if quantity <= 0:
		return 0
	return ceili(float(quantity) / float(maxi(stack_size, 1)))
