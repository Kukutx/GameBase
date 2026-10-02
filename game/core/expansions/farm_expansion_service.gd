class_name FarmExpansionService
extends Node

signal expansion_completed(expansion_id: StringName, housing_id: StringName, capacity: int)

const STATE_KEY := &"farm_expansions:completed"
const CAPACITY_KEY := &"farm_expansions:capacity_entitlements"

var _purchasing: Dictionary = {}

func get_expansion(expansion_id: StringName) -> FarmExpansionData:
	return ContentDB.get_farm_expansion(expansion_id)

func is_completed(expansion_id: StringName) -> bool:
	var state := _get_state()
	if bool(state.get(String(expansion_id), false)):
		return true
	var data := get_expansion(expansion_id)
	return data != null and data.capacity_after > 0 and _get_entitled_capacity(data.housing_id) >= data.capacity_after

func is_available(expansion_id: StringName) -> bool:
	var data := get_expansion(expansion_id)
	if data == null or is_completed(expansion_id):
		return false
	if data.required_world_flag != &"" and not WorldState.get_bool(data.required_world_flag):
		return false
	for prerequisite: StringName in data.prerequisites:
		if not is_completed(prerequisite):
			return false
	return true

func can_purchase(expansion_id: StringName) -> bool:
	var data := get_expansion(expansion_id)
	if data == null or not is_available(expansion_id):
		return false
	if PlayerState.money < data.money_cost:
		return false
	return InventoryState.can_apply_transaction(data.materials, {})

func purchase(expansion_id: StringName) -> bool:
	var purchase_key := String(expansion_id)
	if _purchasing.has(purchase_key):
		return false
	var data := get_expansion(expansion_id)
	if data == null or not is_available(expansion_id):
		return false
	if not can_purchase(expansion_id):
		GameEvents.toast("Missing money or materials for %s" % data.display_name)
		return false
	_purchasing[purchase_key] = true
	var inventory_snapshot := InventoryState.to_save_data()
	if not InventoryState.apply_transaction_atomic(data.materials, {}):
		_purchasing.erase(purchase_key)
		GameEvents.toast("Materials changed before %s could be purchased" % data.display_name)
		return false
	if data.money_cost > 0 and not PlayerState.spend_money(data.money_cost):
		InventoryState.load_save_data(inventory_snapshot)
		_purchasing.erase(purchase_key)
		GameEvents.toast("Money changed before %s could be purchased" % data.display_name)
		return false
	var state := _get_state()
	state[String(expansion_id)] = true
	WorldState.set_value(STATE_KEY, state)
	var capacities := _get_capacity_state()
	capacities[String(data.housing_id)] = maxi(int(capacities.get(String(data.housing_id), 0)), data.capacity_after)
	WorldState.set_value(CAPACITY_KEY, capacities)
	expansion_completed.emit(expansion_id, data.housing_id, data.capacity_after)
	_purchasing.erase(purchase_key)
	GameEvents.toast("Expansion complete: %s" % data.display_name)
	return true

func get_capacity(housing_id: StringName, base_capacity: int) -> int:
	var result := maxi(maxi(base_capacity, 1), _get_entitled_capacity(housing_id))
	for data: FarmExpansionData in ContentDB.get_all_farm_expansions():
		if data == null or data.housing_id != housing_id or not is_completed(data.id):
			continue
		result = maxi(result, data.capacity_after)
	return result

func get_next_expansion_for_housing(housing_id: StringName) -> FarmExpansionData:
	var candidates: Array[FarmExpansionData] = []
	for data: FarmExpansionData in ContentDB.get_all_farm_expansions():
		if data != null and data.housing_id == housing_id and not is_completed(data.id):
			candidates.append(data)
	candidates.sort_custom(func(a: FarmExpansionData, b: FarmExpansionData) -> bool: return a.capacity_after < b.capacity_after)
	for data: FarmExpansionData in candidates:
		if is_available(data.id):
			return data
	return null

func get_summary() -> String:
	var parts := PackedStringArray()
	for housing_id: StringName in [&"starter_coop", &"starter_barn"]:
		parts.append("%s %d slots" % [String(housing_id).trim_prefix("starter_").capitalize(), get_capacity(housing_id, 4)])
	return " · ".join(parts)

func reconcile_loaded_state() -> void:
	# Old saves only stored completed expansion IDs. Backfill a per-housing capacity
	# entitlement while those resources are still known. Future ID renames/removals
	# can then preserve what the player already paid for instead of shrinking a
	# coop/barn back to its base capacity.
	var state := _get_state()
	var capacities := _get_capacity_state()
	var changed := false
	for data: FarmExpansionData in ContentDB.get_all_farm_expansions():
		if data == null or not bool(state.get(String(data.id), false)):
			continue
		var key := String(data.housing_id)
		var next_capacity := maxi(int(capacities.get(key, 0)), data.capacity_after)
		if int(capacities.get(key, 0)) != next_capacity:
			capacities[key] = next_capacity
			changed = true
	if changed:
		WorldState.set_value(CAPACITY_KEY, capacities)

func _get_state() -> Dictionary:
	var raw: Variant = WorldState.get_value(STATE_KEY, {})
	if not raw is Dictionary:
		return {}
	var normalized: Dictionary = {}
	for raw_key: Variant in (raw as Dictionary).keys():
		var value: Variant = (raw as Dictionary)[raw_key]
		if value is bool and bool(value):
			normalized[String(raw_key)] = true
	return normalized

func _get_capacity_state() -> Dictionary:
	var raw: Variant = WorldState.get_value(CAPACITY_KEY, {})
	if not raw is Dictionary:
		return {}
	var normalized: Dictionary = {}
	for raw_key: Variant in (raw as Dictionary).keys():
		var value: Variant = (raw as Dictionary)[raw_key]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			continue
		var capacity := maxi(int(value), 0)
		if capacity > 0:
			normalized[String(raw_key)] = capacity
	return normalized

func _get_entitled_capacity(housing_id: StringName) -> int:
	if housing_id == &"":
		return 0
	return int(_get_capacity_state().get(String(housing_id), 0))
