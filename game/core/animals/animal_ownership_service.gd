class_name AnimalOwnershipService
extends Node

signal ownership_changed(location_id: StringName)
signal animal_purchased(instance_id: StringName, animal_id: StringName, price: int)
signal animal_renamed(instance_id: StringName, custom_name: String)
signal animal_sold(instance_id: StringName, refund: int)
signal animal_fed(instance_id: StringName)
signal housing_fed(housing_id: StringName, count: int)

const OWNERSHIP_KEY := &"animal:ownership"
const INITIALIZED_KEY := &"animal:ownership_initialized"
const SEQUENCE_KEY := &"animal:ownership_sequence"

var _housing: Dictionary = {}
var _feeding_housing: Dictionary = {}
var _purchase_busy := false

func reset_new_game() -> void:
	WorldState.erase(OWNERSHIP_KEY)
	WorldState.erase(INITIALIZED_KEY)
	WorldState.erase(SEQUENCE_KEY)
	ensure_legacy_defaults()

func ensure_legacy_defaults() -> void:
	var initialized_raw: Variant = WorldState.get_value(INITIALIZED_KEY, false)
	if initialized_raw is bool and bool(initialized_raw):
		return
	var records := _get_records()
	if records.is_empty():
		records.append(_make_record(&"starter_chicken_01", &"chicken", &"starter_town", &"starter_coop", 0, "Chicken"))
		records.append(_make_record(&"starter_cow_01", &"cow", &"starter_town", &"starter_barn", 0, "Cow"))
		_set_records(records)
	WorldState.set_value(SEQUENCE_KEY, maxi(_safe_int(WorldState.get_value(SEQUENCE_KEY, 2), 2), 2))
	WorldState.set_value(INITIALIZED_KEY, true)

func register_housing(housing_id: StringName, location_id: StringName, housing_type: StringName, capacity: int) -> void:
	if housing_id == &"" or location_id == &"" or housing_type == &"" or capacity <= 0:
		return
	_housing[String(housing_id)] = {
		"id": String(housing_id),
		"location_id": String(location_id),
		"housing_type": String(housing_type),
		"capacity": capacity,
	}
	ensure_legacy_defaults()

func unregister_housing(housing_id: StringName) -> void:
	_housing.erase(String(housing_id))

func get_owned(location_id: StringName = &"", housing_id: StringName = &"") -> Array[Dictionary]:
	ensure_legacy_defaults()
	var result: Array[Dictionary] = []
	var seen_instances: Dictionary = {}
	for raw: Variant in _get_records():
		if not raw is Dictionary:
			continue
		var record: Dictionary = raw
		var instance_id := StringName(String(record.get("instance_id", "")))
		var animal_id := StringName(String(record.get("animal_id", "")))
		var record_location_id := StringName(String(record.get("location_id", "")))
		var record_housing_id := StringName(String(record.get("housing_id", "")))
		# Keep malformed/orphan records in raw WorldState so restoring content can
		# resurrect them, but gameplay must not count invisible/broken ownership
		# records against housing capacity or spawn the same instance twice.
		if instance_id == &"" or animal_id == &"" or record_location_id == &"" or record_housing_id == &"":
			continue
		if ContentDB.get_farm_animal(animal_id) == null or seen_instances.has(String(instance_id)):
			continue
		seen_instances[String(instance_id)] = true
		if location_id != &"" and record_location_id != location_id:
			continue
		if housing_id != &"" and record_housing_id != housing_id:
			continue
		result.append(record.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0)))
	return result

func get_record(instance_id: StringName) -> Dictionary:
	if instance_id == &"":
		return {}
	for record: Dictionary in get_owned():
		if StringName(String(record.get("instance_id", ""))) == instance_id:
			return record
	return {}

func rename_animal(instance_id: StringName, requested_name: String) -> bool:
	var next_name := requested_name.strip_edges()
	if instance_id == &"" or next_name.is_empty() or next_name.length() > 20:
		return false
	var records := _get_records()
	for index in range(records.size()):
		if not records[index] is Dictionary:
			continue
		var record: Dictionary = records[index]
		if StringName(String(record.get("instance_id", ""))) != instance_id:
			continue
		record["custom_name"] = next_name
		records[index] = record
		_set_records(records)
		var location_id := StringName(String(record.get("location_id", "")))
		ownership_changed.emit(location_id)
		animal_renamed.emit(instance_id, next_name)
		GameEvents.toast("Renamed animal to %s" % next_name)
		return true
	return false

func sell_animal(instance_id: StringName) -> int:
	if instance_id == &"":
		return 0
	var records := _get_records()
	for index in range(records.size()):
		if not records[index] is Dictionary:
			continue
		var record: Dictionary = records[index]
		if StringName(String(record.get("instance_id", ""))) != instance_id:
			continue
		var data := ContentDB.get_farm_animal(StringName(String(record.get("animal_id", ""))))
		if data == null:
			return 0
		var refund := maxi(int(round(float(data.purchase_price) * 0.5)), 0)
		var location_id := StringName(String(record.get("location_id", "")))
		records.remove_at(index)
		_set_records(records)
		WorldState.erase(_animal_state_key(instance_id))
		if refund > 0:
			PlayerState.add_money(refund)
		ownership_changed.emit(location_id)
		animal_sold.emit(instance_id, refund)
		GameEvents.toast("Sold %s for %dg" % [data.display_name, refund])
		return refund
	return 0

func get_housing_capacity(housing_id: StringName) -> int:
	var raw: Variant = _housing.get(String(housing_id), {})
	var base_capacity := maxi(int(raw.get("capacity", 0)), 0) if raw is Dictionary else 0
	return FarmExpansionState.get_capacity(housing_id, base_capacity) if base_capacity > 0 else 0

func get_housing_occupancy(housing_id: StringName) -> int:
	return get_owned(&"", housing_id).size()

func get_available_slots(location_id: StringName, housing_type: StringName) -> int:
	var total := 0
	for raw: Variant in _housing.values():
		if not raw is Dictionary:
			continue
		var housing: Dictionary = raw
		if StringName(String(housing.get("location_id", ""))) != location_id:
			continue
		if StringName(String(housing.get("housing_type", ""))) != housing_type:
			continue
		var housing_id := StringName(String(housing.get("id", "")))
		total += get_housing_capacity(housing_id) - get_housing_occupancy(housing_id)
	return maxi(total, 0)

func get_unfed_count(housing_id: StringName) -> int:
	var count := 0
	for record: Dictionary in get_owned(&"", housing_id):
		var instance_id := StringName(String(record.get("instance_id", "")))
		if instance_id == &"":
			continue
		var state := _get_animal_state(instance_id)
		if int(state.get("last_fed_day", WorldClock.day)) < WorldClock.day:
			count += 1
	return count

func feed_housing(housing_id: StringName, feed_item_id: StringName = &"hay") -> int:
	var housing_key := String(housing_id)
	if _feeding_housing.has(housing_key):
		return 0
	_feeding_housing[housing_key] = true
	var fed := _feed_housing_internal(housing_id, feed_item_id)
	_feeding_housing.erase(housing_key)
	return fed

func _feed_housing_internal(housing_id: StringName, feed_item_id: StringName) -> int:
	if housing_id == &"" or feed_item_id == &"":
		return 0
	var fed := 0
	for record: Dictionary in get_owned(&"", housing_id):
		var instance_id := StringName(String(record.get("instance_id", "")))
		var animal_id := StringName(String(record.get("animal_id", "")))
		var data := ContentDB.get_farm_animal(animal_id)
		if instance_id == &"" or data == null or data.feed_item_id != feed_item_id:
			continue
		var state := _get_animal_state(instance_id)
		if int(state.get("last_fed_day", WorldClock.day)) >= WorldClock.day:
			continue
		if not InventoryState.remove_item(feed_item_id, 1):
			break
		state["last_fed_day"] = WorldClock.day
		if not state.has("last_processed_day"):
			state["last_processed_day"] = WorldClock.day
		WorldState.set_value(_animal_state_key(instance_id), state)
		animal_fed.emit(instance_id)
		fed += 1
	if fed > 0:
		housing_fed.emit(housing_id, fed)
	return fed

func can_purchase(animal_id: StringName, location_id: StringName) -> bool:
	var data := ContentDB.get_farm_animal(animal_id)
	if data == null or data.purchase_price <= 0:
		return false
	if PlayerState.money < data.purchase_price:
		return false
	return _find_housing_with_space(location_id, data.housing_type) != &""

func purchase(animal_id: StringName, location_id: StringName) -> StringName:
	if _purchase_busy:
		return &""
	_purchase_busy = true
	var result := _purchase_internal(animal_id, location_id)
	_purchase_busy = false
	return result

func _purchase_internal(animal_id: StringName, location_id: StringName) -> StringName:
	var data := ContentDB.get_farm_animal(animal_id)
	if data == null:
		return &""
	var housing_id := _find_housing_with_space(location_id, data.housing_type)
	if housing_id == &"":
		GameEvents.toast("No free %s slots" % String(data.housing_type).capitalize())
		return &""
	if not PlayerState.spend_money(data.purchase_price):
		GameEvents.toast("Not enough money")
		return &""
	# Money callbacks can synchronously change animal ownership or housing. Recheck
	# after payment so a slot that was consumed during the callback cannot be
	# overbooked by this purchase.
	housing_id = _find_housing_with_space(location_id, data.housing_type)
	if housing_id == &"":
		PlayerState.add_money(data.purchase_price)
		GameEvents.toast("Housing changed before the purchase completed")
		return &""
	var sequence := _next_unique_sequence(animal_id)
	WorldState.set_value(SEQUENCE_KEY, sequence)
	var instance_id := StringName("owned_%s_%04d" % [String(animal_id), sequence])
	var slot_index := _first_free_slot(housing_id)
	var node_name := "%s_%02d" % [data.display_name.validate_node_name(), sequence]
	var records := _get_records()
	records.append(_make_record(instance_id, animal_id, location_id, housing_id, slot_index, node_name))
	_set_records(records)
	WorldState.set_value(_animal_state_key(instance_id), {
		"happiness": 50,
		"last_product_day": WorldClock.day,
		"last_pet_day": 0,
		"last_fed_day": WorldClock.day,
		"last_processed_day": WorldClock.day,
	})
	ownership_changed.emit(location_id)
	animal_purchased.emit(instance_id, animal_id, data.purchase_price)
	GameEvents.toast("Bought %s for %dg" % [data.display_name, data.purchase_price])
	return instance_id

func _next_unique_sequence(animal_id: StringName) -> int:
	var used_ids: Dictionary = {}
	for raw: Variant in _get_records():
		if raw is Dictionary:
			var instance_id := String((raw as Dictionary).get("instance_id", ""))
			if not instance_id.is_empty():
				used_ids[instance_id] = true
	var sequence := maxi(_safe_int(WorldState.get_value(SEQUENCE_KEY, 2), 2) + 1, 3)
	while used_ids.has("owned_%s_%04d" % [String(animal_id), sequence]):
		sequence += 1
	return sequence

func _find_housing_with_space(location_id: StringName, housing_type: StringName) -> StringName:
	var ids: Array[String] = []
	for raw_id: Variant in _housing.keys():
		ids.append(String(raw_id))
	ids.sort()
	for raw_id: String in ids:
		var housing: Dictionary = _housing[raw_id]
		if StringName(String(housing.get("location_id", ""))) != location_id:
			continue
		if StringName(String(housing.get("housing_type", ""))) != housing_type:
			continue
		var housing_id := StringName(raw_id)
		if get_housing_occupancy(housing_id) < get_housing_capacity(housing_id):
			return housing_id
	return &""

func _first_free_slot(housing_id: StringName) -> int:
	var used: Dictionary = {}
	# Reserve raw slot indices even for currently unknown animal definitions so a
	# later content restore cannot make two records materialize in the same slot.
	for raw: Variant in _get_records():
		if not raw is Dictionary:
			continue
		var record: Dictionary = raw
		if StringName(String(record.get("housing_id", ""))) == housing_id:
			used[int(record.get("slot_index", 0))] = true
	var capacity := get_housing_capacity(housing_id)
	for index in range(capacity):
		if not used.has(index):
			return index
	return maxi(capacity, 0)

func _make_record(instance_id: StringName, animal_id: StringName, location_id: StringName, housing_id: StringName, slot_index: int, node_name: String) -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"animal_id": String(animal_id),
		"location_id": String(location_id),
		"housing_id": String(housing_id),
		"slot_index": maxi(slot_index, 0),
		"node_name": node_name,
	}

func _get_records() -> Array:
	var raw: Variant = WorldState.get_value(OWNERSHIP_KEY, [])
	if not raw is Array:
		return []
	var normalized: Array = []
	for raw_record: Variant in raw:
		if not raw_record is Dictionary:
			continue
		var record: Dictionary = (raw_record as Dictionary).duplicate(true)
		record["instance_id"] = String(record.get("instance_id", ""))
		record["animal_id"] = String(record.get("animal_id", ""))
		record["location_id"] = String(record.get("location_id", ""))
		record["housing_id"] = String(record.get("housing_id", ""))
		record["slot_index"] = maxi(_safe_int(record.get("slot_index", 0), 0), 0)
		record["node_name"] = String(record.get("node_name", ""))
		if record.has("custom_name"):
			record["custom_name"] = String(record.get("custom_name", ""))
		normalized.append(record)
	return normalized

func _set_records(records: Array) -> void:
	WorldState.set_value(OWNERSHIP_KEY, records.duplicate(true))

func _animal_state_key(instance_id: StringName) -> StringName:
	return StringName("animal:%s" % String(instance_id))

func _get_animal_state(instance_id: StringName) -> Dictionary:
	var raw: Variant = WorldState.get_value(_animal_state_key(instance_id), {})
	if not raw is Dictionary:
		return {}
	var state: Dictionary = (raw as Dictionary).duplicate(true)
	var current_day := maxi(WorldClock.day, 1)
	if state.has("happiness"):
		state["happiness"] = clampi(_safe_int(state.get("happiness", 50), 50), 0, 100)
	for key: String in ["last_product_day", "last_pet_day", "last_fed_day"]:
		if state.has(key):
			# A malformed date should not grant free products/pets or punish the player
			# with a missed-feed state. Treat unparseable values as observed today.
			state[key] = clampi(_safe_int(state.get(key, current_day), current_day), 0, current_day)
	if state.has("last_processed_day"):
		state["last_processed_day"] = clampi(_safe_int(state.get("last_processed_day", current_day), current_day), 1, current_day)
	return state

func _safe_int(value: Variant, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback
