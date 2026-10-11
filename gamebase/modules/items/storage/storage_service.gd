class_name StorageService
extends Node

signal container_changed(container_id: StringName)

var _mutating_containers: Dictionary = {}

func store_item(container_id: StringName, item_id: StringName, quantity: int = 1, max_slots: int = 24) -> int:
	if container_id == &"" or item_id == &"" or quantity <= 0 or max_slots <= 0:
		return 0
	var container_key := String(container_id)
	if _mutating_containers.has(container_key):
		return 0
	var item := ItemData.find(item_id)
	if item == null:
		return 0
	var available := mini(quantity, InventoryState.get_quantity(item_id))
	if available <= 0:
		return 0
	var data := _get_container_data(container_id)
	var key := String(item_id)
	var current := maxi(int(data.get(key, 0)), 0)
	var used_slots := _used_slots(data)
	var current_stacks := _stack_count(current, item.max_stack)
	var partial_capacity := current_stacks * item.max_stack - current if current_stacks > 0 else 0
	var free_slots := maxi(max_slots - used_slots, 0)
	var capacity := partial_capacity + free_slots * item.max_stack
	var accepted := mini(available, capacity)
	if accepted <= 0:
		return 0
	_mutating_containers[container_key] = true
	if not InventoryState.apply_transaction_atomic({String(item_id): accepted}, {}):
		_mutating_containers.erase(container_key)
		return 0
	data[key] = current + accepted
	WorldState.set_value(_state_key(container_id), data.duplicate(true))
	_mutating_containers.erase(container_key)
	container_changed.emit(container_id)
	return accepted

func take_item(container_id: StringName, item_id: StringName, quantity: int = 1) -> int:
	if container_id == &"" or item_id == &"" or quantity <= 0:
		return 0
	var container_key := String(container_id)
	if _mutating_containers.has(container_key):
		return 0
	var item := ItemData.find(item_id)
	if item == null:
		return 0
	var data := _get_container_data(container_id)
	var key := String(item_id)
	var current := maxi(int(data.get(key, 0)), 0)
	var requested := mini(quantity, current)
	if requested <= 0:
		return 0
	var accepted := mini(requested, InventoryState.get_add_capacity(item))
	if accepted <= 0:
		return 0
	_mutating_containers[container_key] = true
	if not InventoryState.apply_transaction_atomic({}, {String(item_id): accepted}):
		_mutating_containers.erase(container_key)
		return 0
	current -= accepted
	if current <= 0:
		data.erase(key)
	else:
		data[key] = current
	WorldState.set_value(_state_key(container_id), data.duplicate(true))
	_mutating_containers.erase(container_key)
	container_changed.emit(container_id)
	return accepted

func get_quantity(container_id: StringName, item_id: StringName) -> int:
	return maxi(int(_get_container_data(container_id).get(String(item_id), 0)), 0)

func get_entries(container_id: StringName) -> Array[Dictionary]:
	var data := _get_container_data(container_id)
	var result: Array[Dictionary] = []
	for raw_key: Variant in data.keys():
		var item_id := StringName(String(raw_key))
		var item := ItemData.find(item_id)
		var quantity := maxi(int(data[raw_key]), 0)
		if item == null or quantity <= 0:
			continue
		result.append({
			"id": String(item_id),
			"display_name": item.display_name,
			"quantity": quantity,
			"stacks": _stack_count(quantity, item.max_stack),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["display_name"]) < String(b["display_name"]))
	return result

func get_used_slots(container_id: StringName) -> int:
	return _used_slots(_get_container_data(container_id))

func clear_container(container_id: StringName) -> void:
	if container_id == &"":
		return
	WorldState.erase(_state_key(container_id))
	container_changed.emit(container_id)

func _get_container_data(container_id: StringName) -> Dictionary:
	var raw: Variant = WorldState.get_value(_state_key(container_id), {})
	if not raw is Dictionary:
		return {}
	var normalized: Dictionary = {}
	for raw_key: Variant in (raw as Dictionary).keys():
		var raw_quantity: Variant = (raw as Dictionary)[raw_key]
		if typeof(raw_quantity) != TYPE_INT and typeof(raw_quantity) != TYPE_FLOAT:
			continue
		var quantity := maxi(int(raw_quantity), 0)
		if quantity > 0:
			normalized[String(raw_key)] = quantity
	return normalized

func _set_container_data(container_id: StringName, data: Dictionary) -> void:
	WorldState.set_value(_state_key(container_id), data.duplicate(true))
	container_changed.emit(container_id)

func _used_slots(data: Dictionary) -> int:
	var total := 0
	for raw_key: Variant in data.keys():
		var item := ItemData.find(StringName(String(raw_key)))
		if item == null:
			continue
		total += _stack_count(maxi(int(data[raw_key]), 0), item.max_stack)
	return total

func _stack_count(quantity: int, max_stack: int) -> int:
	if quantity <= 0:
		return 0
	return int(ceil(float(quantity) / float(maxi(max_stack, 1))))

func _state_key(container_id: StringName) -> StringName:
	return StringName("storage:%s" % String(container_id))
