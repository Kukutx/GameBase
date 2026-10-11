class_name InventoryStore
extends Node

signal changed
signal item_added(item_id: StringName, quantity: int)
signal item_removed(item_id: StringName, quantity: int)

@export_range(1, 200, 1) var max_slots := 24

# Stored as aggregate quantities for save stability. Slot stacks are derived from
# quantity/max_stack, which keeps the API compact while supporting repeated stacks.
var _items: Dictionary = {}

func add_item(item: ItemData, quantity: int = 1) -> int:
	if item == null or item.id == &"" or quantity <= 0:
		return quantity
	var key := String(item.id)
	var current: Dictionary = _items.get(key, {})
	var current_quantity := maxi(int(current.get("quantity", 0)), 0)
	var stack_size := maxi(item.max_stack, 1)
	var capacity := get_add_capacity(item)
	var accepted := mini(quantity, capacity)
	if accepted <= 0:
		return quantity
	_items[key] = {
		"quantity": current_quantity + accepted,
		"display_name": item.display_name if not item.display_name.is_empty() else key,
		"max_stack": stack_size,
	}
	changed.emit()
	item_added.emit(item.id, accepted)
	return quantity - accepted

func get_add_capacity(item: ItemData) -> int:
	if item == null or item.id == &"":
		return 0
	var key := String(item.id)
	var current: Dictionary = _items.get(key, {})
	var current_quantity := maxi(int(current.get("quantity", 0)), 0)
	var stack_size := maxi(item.max_stack, 1)
	var current_slots := _stack_count(current_quantity, stack_size)
	var other_slots := get_used_slots() - current_slots
	var slots_available_for_item := maxi(max_slots - other_slots, 0)
	var max_quantity := slots_available_for_item * stack_size
	return maxi(max_quantity - current_quantity, 0)

func can_add_item(item: ItemData, quantity: int = 1) -> bool:
	return quantity <= 0 or (item != null and get_add_capacity(item) >= quantity)

func can_add_items_by_id(items: Dictionary) -> bool:
	return can_apply_transaction({}, items)

func apply_transaction_atomic(removals: Dictionary, additions: Dictionary) -> bool:
	var probe := InventoryStore.new()
	probe.max_slots = max_slots
	probe.load_save_data(to_save_data())
	var removed_events: Array[Dictionary] = []
	var added_events: Array[Dictionary] = []
	for raw_id: Variant in removals.keys():
		var item_id := StringName(String(raw_id))
		var quantity := _strict_transaction_quantity(removals[raw_id])
		if quantity < 0:
			probe.free()
			return false
		if quantity == 0:
			continue
		if not probe.remove_item(item_id, quantity):
			probe.free()
			return false
		removed_events.append({"id": item_id, "quantity": quantity})
	for raw_id: Variant in additions.keys():
		var item_id := StringName(String(raw_id))
		var quantity := _strict_transaction_quantity(additions[raw_id])
		if quantity < 0:
			probe.free()
			return false
		if quantity == 0:
			continue
		if probe.add_item_by_id(item_id, quantity) > 0:
			probe.free()
			return false
		added_events.append({"id": item_id, "quantity": quantity})
	if removed_events.is_empty() and added_events.is_empty():
		probe.free()
		return true
	var next_data := probe.to_save_data()
	probe.free()
	_items = next_data.duplicate(true)
	changed.emit()
	for event: Dictionary in removed_events:
		item_removed.emit(event["id"] as StringName, int(event["quantity"]))
	for event: Dictionary in added_events:
		item_added.emit(event["id"] as StringName, int(event["quantity"]))
	return true

func can_apply_transaction(removals: Dictionary, additions: Dictionary) -> bool:
	var probe := InventoryStore.new()
	probe.max_slots = max_slots
	probe.load_save_data(to_save_data())
	for raw_id: Variant in removals.keys():
		var quantity := _strict_transaction_quantity(removals[raw_id])
		if quantity < 0:
			probe.free()
			return false
		if quantity > 0 and not probe.remove_item(StringName(String(raw_id)), quantity):
			probe.free()
			return false
	for raw_id: Variant in additions.keys():
		var quantity := _strict_transaction_quantity(additions[raw_id])
		if quantity < 0:
			probe.free()
			return false
		if quantity == 0:
			continue
		if probe.add_item_by_id(StringName(String(raw_id)), quantity) > 0:
			probe.free()
			return false
	probe.free()
	return true

func apply_refund_snapshot_atomic(snapshot: Dictionary) -> bool:
	var probe := InventoryStore.new()
	probe.max_slots = max_slots
	probe.load_save_data(to_save_data())
	var added_events: Array[Dictionary] = []
	for raw_id: Variant in snapshot.keys():
		var item_id := StringName(String(raw_id))
		var raw_entry: Variant = snapshot[raw_id]
		var quantity := 0
		var legacy_name := String(item_id)
		var legacy_stack := 99
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			quantity = _safe_nonnegative_int(entry.get("quantity", 0))
			var raw_name: Variant = entry.get("display_name", legacy_name)
			if raw_name is String or raw_name is StringName:
				legacy_name = String(raw_name)
			legacy_stack = maxi(_safe_positive_int(entry.get("max_stack", legacy_stack), legacy_stack), 1)
		else:
			quantity = _safe_nonnegative_int(raw_entry)
		if item_id == &"" or quantity <= 0:
			continue
		var item := ItemCatalog.get_item(item_id)
		if item != null:
			if probe.add_item(item, quantity) > 0:
				probe.free()
				return false
		else:
			var key := String(item_id)
			var current: Dictionary = probe._items.get(key, {})
			probe._items[key] = {
				"quantity": maxi(int(current.get("quantity", 0)), 0) + quantity,
				"display_name": String(current.get("display_name", legacy_name)),
				"max_stack": maxi(int(current.get("max_stack", legacy_stack)), 1),
			}
		added_events.append({"id": item_id, "quantity": quantity})
	if added_events.is_empty():
		probe.free()
		return true
	var next_data := probe.to_save_data()
	probe.free()
	_items = next_data.duplicate(true)
	changed.emit()
	for event: Dictionary in added_events:
		item_added.emit(event["id"] as StringName, int(event["quantity"]))
	return true

func add_item_by_id(item_id: StringName, quantity: int = 1) -> int:
	var item := ItemCatalog.get_item(item_id)
	return add_item(item, quantity) if item != null else quantity

func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	var key := String(item_id)
	if quantity <= 0 or not _items.has(key):
		return false
	var current: Dictionary = _items[key]
	var current_quantity := int(current.get("quantity", 0))
	if current_quantity < quantity:
		return false
	current_quantity -= quantity
	if current_quantity <= 0:
		_items.erase(key)
	else:
		current["quantity"] = current_quantity
		_items[key] = current
	changed.emit()
	item_removed.emit(item_id, quantity)
	return true

func has_item(item_id: StringName, quantity: int = 1) -> bool:
	return quantity <= 0 or get_quantity(item_id) >= quantity

func get_quantity(item_id: StringName) -> int:
	var entry: Dictionary = _items.get(String(item_id), {})
	return int(entry.get("quantity", 0))

func get_used_slots() -> int:
	var used := 0
	for raw_key: Variant in _items.keys():
		var key := String(raw_key)
		var raw: Variant = _items[raw_key]
		if not raw is Dictionary:
			continue
		# Preserve unknown legacy items in save data, but do not let content that
		# no longer exists permanently consume usable inventory capacity.
		if ItemCatalog.get_item(StringName(key)) == null:
			continue
		var entry: Dictionary = raw
		used += _stack_count(int(entry.get("quantity", 0)), maxi(int(entry.get("max_stack", 99)), 1))
	return used

func get_free_slots() -> int:
	return maxi(max_slots - get_used_slots(), 0)

func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in _items.keys():
		var entry: Dictionary = _items[key]
		var known := ItemCatalog.get_item(StringName(key)) != null
		var max_stack := maxi(int(entry.get("max_stack", 99)), 1)
		result.append({
			"id": key,
			"display_name": String(entry.get("display_name", key)),
			"quantity": int(entry.get("quantity", 0)),
			"max_stack": max_stack,
			"slots": _stack_count(int(entry.get("quantity", 0)), max_stack) if known else 0,
			"known": known,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["display_name"]) < String(b["display_name"]))
	return result

func get_slot_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in get_entries():
		if not bool(entry.get("known", true)):
			continue
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
	changed.emit()

func to_save_data() -> Dictionary:
	return _items.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	_items.clear()
	for raw_key: Variant in data.keys():
		var key := String(raw_key)
		var raw_entry: Variant = data[raw_key]
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var quantity := _safe_nonnegative_int(entry.get("quantity", 0))
		if quantity <= 0:
			continue
		var item := ItemCatalog.get_item(StringName(key))
		var display_name := key
		var raw_name: Variant = entry.get("display_name", key)
		if raw_name is String or raw_name is StringName:
			display_name = String(raw_name)
		_items[key] = {
			"quantity": quantity,
			"display_name": item.display_name if item != null else display_name,
			"max_stack": item.max_stack if item != null else _safe_positive_int(entry.get("max_stack", 99), 99),
		}
	changed.emit()

func _strict_transaction_quantity(value: Variant) -> int:
	if typeof(value) != TYPE_INT:
		return -1
	return maxi(int(value), 0)

func _safe_nonnegative_int(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	return maxi(int(value), 0)

func _safe_positive_int(value: Variant, fallback: int = 1) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return maxi(fallback, 1)
	return maxi(int(value), 1)

func _stack_count(quantity: int, stack_size: int) -> int:
	if quantity <= 0:
		return 0
	return ceili(float(quantity) / float(maxi(stack_size, 1)))
