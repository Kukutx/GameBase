class_name AnimalOwnershipService
extends Node

signal ownership_changed(location_id: StringName)
signal animal_purchased(instance_id: StringName, animal_id: StringName, price: int)
signal animal_renamed(instance_id: StringName, custom_name: String)
signal animal_sold(instance_id: StringName, refund: int)
signal animal_fed(instance_id: StringName)
signal housing_fed(housing_id: StringName, count: int)

const OWNERSHIP_KEY := &"animal:ownership"
const SEQUENCE_KEY := &"animal:ownership_sequence"

var _housing: Dictionary = {}
var _feeding_housing: Dictionary = {}
var _purchase_busy := false

func reset_new_game() -> void:
	WorldState.erase(OWNERSHIP_KEY)
	WorldState.erase(SEQUENCE_KEY)

## Gives the player an animal without payment, for example a game's starting
## animals. A granted animal has no history yet, so it starts as an animal that
## has lived on the farm (its product is ready). Returns false when `animal_id` is not content or `instance_id` is
## already owned.
func grant_animal(instance_id: StringName, animal_id: StringName, location_id: StringName, housing_id: StringName, slot_index: int) -> bool:
	var data := FarmAnimalData.find(animal_id)
	if data == null or instance_id == &"" or location_id == &"" or housing_id == &"" or not get_record(instance_id).is_empty():
		return false
	_add_record(instance_id, animal_id, location_id, housing_id, slot_index, data.display_name.validate_node_name())
	ownership_changed.emit(location_id)
	return true

func register_housing(housing_id: StringName, location_id: StringName, housing_type: StringName, capacity: int, display_name: String) -> void:
	if housing_id == &"" or location_id == &"" or housing_type == &"" or capacity <= 0:
		return
	_housing[String(housing_id)] = {
		"id": String(housing_id),
		"location_id": String(location_id),
		"housing_type": String(housing_type),
		"capacity": capacity,
		"display_name": display_name,
	}

func unregister_housing(housing_id: StringName) -> void:
	_housing.erase(String(housing_id))

## The housings registered at `location_id`, in the order they registered (their
## scene order).
func get_housing_ids(location_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw: Variant in _housing.values():
		var housing: Dictionary = raw
		if StringName(String(housing["location_id"])) == location_id:
			result.append(StringName(String(housing["id"])))
	return result

func get_housing_name(housing_id: StringName) -> String:
	var raw: Variant = _housing.get(String(housing_id), {})
	return String((raw as Dictionary).get("display_name", "")) if raw is Dictionary else ""

## The items the animals that can live at `location_id` eat, in content order.
func get_feed_item_ids(location_id: StringName) -> Array[StringName]:
	var housing_types: Dictionary = {}
	for housing_id: StringName in get_housing_ids(location_id):
		housing_types[String(_housing[String(housing_id)]["housing_type"])] = true
	var result: Array[StringName] = []
	for data: FarmAnimalData in FarmAnimalData.find_all():
		if housing_types.has(String(data.housing_type)) and data.feed_item_id != &"" and not result.has(data.feed_item_id):
			result.append(data.feed_item_id)
	return result

func get_owned(location_id: StringName = &"", housing_id: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _get_records():
		if location_id != &"" and StringName(String(record["location_id"])) != location_id:
			continue
		if housing_id != &"" and StringName(String(record["housing_id"])) != housing_id:
			continue
		result.append(record)
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
		var record: Dictionary = records[index]
		if StringName(String(record["instance_id"])) != instance_id:
			continue
		record["custom_name"] = next_name
		records[index] = record
		_set_records(records)
		var location_id := StringName(String(record.get("location_id", "")))
		ownership_changed.emit(location_id)
		animal_renamed.emit(instance_id, next_name)
		# The name is the player's own text and is shown as typed.
		GameEvents.toast(tr("Renamed animal to %s") % next_name)
		return true
	return false

func sell_animal(instance_id: StringName) -> int:
	if instance_id == &"":
		return 0
	var records := _get_records()
	for index in range(records.size()):
		var record: Dictionary = records[index]
		if StringName(String(record["instance_id"])) != instance_id:
			continue
		var data := FarmAnimalData.find(StringName(String(record.get("animal_id", ""))))
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
		GameEvents.toastf("Sold %s for %dg", [data.display_name, refund])
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

## What the animals of `housing_id` that are not fed today eat: feed item id →
## number of animals.
func get_feed_needs(housing_id: StringName) -> Dictionary[StringName, int]:
	var needs: Dictionary[StringName, int] = {}
	for record: Dictionary in get_owned(&"", housing_id):
		var instance_id := StringName(String(record.get("instance_id", "")))
		var data := FarmAnimalData.find(StringName(String(record.get("animal_id", ""))))
		if instance_id == &"" or data == null or data.feed_item_id == &"":
			continue
		if int(_get_animal_state(instance_id).get("last_fed_day", WorldClock.day)) < WorldClock.day:
			needs[data.feed_item_id] = needs.get(data.feed_item_id, 0) + 1
	return needs

## Feeds each animal of `housing_id` that is not fed today one of the item it
## eats, while the inventory has it. Returns how many animals were fed.
func feed_housing(housing_id: StringName) -> int:
	var housing_key := String(housing_id)
	if _feeding_housing.has(housing_key):
		return 0
	_feeding_housing[housing_key] = true
	var fed := _feed_housing_internal(housing_id)
	_feeding_housing.erase(housing_key)
	return fed

func _feed_housing_internal(housing_id: StringName) -> int:
	if housing_id == &"":
		return 0
	var fed := 0
	for record: Dictionary in get_owned(&"", housing_id):
		var instance_id := StringName(String(record.get("instance_id", "")))
		var animal_id := StringName(String(record.get("animal_id", "")))
		var data := FarmAnimalData.find(animal_id)
		if instance_id == &"" or data == null or data.feed_item_id == &"":
			continue
		var state := _get_animal_state(instance_id)
		if int(state.get("last_fed_day", WorldClock.day)) >= WorldClock.day:
			continue
		if not InventoryState.remove_item(data.feed_item_id, 1):
			continue
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
	var data := FarmAnimalData.find(animal_id)
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
	var data := FarmAnimalData.find(animal_id)
	if data == null:
		return &""
	var housing_id := _find_housing_with_space(location_id, data.housing_type)
	if housing_id == &"":
		GameEvents.toastf("No free %s slots", [String(data.housing_type).capitalize()])
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
	_add_record(instance_id, animal_id, location_id, housing_id, slot_index, "%s_%02d" % [data.display_name.validate_node_name(), sequence])
	WorldState.set_value(_animal_state_key(instance_id), {
		"happiness": 50,
		"last_product_day": WorldClock.day,
		"last_pet_day": 0,
		"last_fed_day": WorldClock.day,
		"last_processed_day": WorldClock.day,
	})
	ownership_changed.emit(location_id)
	animal_purchased.emit(instance_id, animal_id, data.purchase_price)
	GameEvents.toastf("Bought %s for %dg", [data.display_name, data.purchase_price])
	return instance_id

func _next_unique_sequence(animal_id: StringName) -> int:
	var used_ids: Dictionary = {}
	for record: Dictionary in _get_records():
		used_ids[String(record["instance_id"])] = true
	var sequence := maxi(SaveValues.whole_number_or(WorldState.get_value(SEQUENCE_KEY, 0), 0), 0) + 1
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
	for record: Dictionary in get_owned(&"", housing_id):
		used[int(record["slot_index"])] = true
	var capacity := get_housing_capacity(housing_id)
	for index in range(capacity):
		if not used.has(index):
			return index
	return maxi(capacity, 0)

func _add_record(instance_id: StringName, animal_id: StringName, location_id: StringName, housing_id: StringName, slot_index: int, node_name: String) -> void:
	var records := _get_records()
	records.append({
		"instance_id": String(instance_id),
		"animal_id": String(animal_id),
		"location_id": String(location_id),
		"housing_id": String(housing_id),
		"slot_index": maxi(slot_index, 0),
		"node_name": node_name,
	})
	_set_records(records)

## The owned animals, without records that are malformed, name an animal that is
## not content, or repeat an instance.
func _get_records() -> Array[Dictionary]:
	var raw: Variant = WorldState.get_value(OWNERSHIP_KEY, [])
	var records: Array[Dictionary] = []
	if not raw is Array:
		return records
	var seen: Dictionary = {}
	for raw_record: Variant in raw:
		if not raw_record is Dictionary:
			continue
		var source: Dictionary = raw_record
		var record := {
			"instance_id": String(source.get("instance_id", "")),
			"animal_id": String(source.get("animal_id", "")),
			"location_id": String(source.get("location_id", "")),
			"housing_id": String(source.get("housing_id", "")),
			"slot_index": maxi(SaveValues.whole_number_or(source.get("slot_index", 0), 0), 0),
			"node_name": String(source.get("node_name", "")),
		}
		if source.has("custom_name"):
			record["custom_name"] = String(source["custom_name"])
		var instance_id: String = record["instance_id"]
		if instance_id.is_empty() or seen.has(instance_id) or String(record["location_id"]).is_empty() or String(record["housing_id"]).is_empty():
			continue
		if FarmAnimalData.find(StringName(String(record["animal_id"]))) == null:
			continue
		seen[instance_id] = true
		records.append(record)
	return records

func _set_records(records: Array[Dictionary]) -> void:
	# Stored as a plain array, the same shape it has when read back from a save.
	var stored: Array = []
	for record: Dictionary in records:
		stored.append(record.duplicate())
	WorldState.set_value(OWNERSHIP_KEY, stored)

func _animal_state_key(instance_id: StringName) -> StringName:
	return StringName("animal:%s" % String(instance_id))

func _get_animal_state(instance_id: StringName) -> Dictionary:
	var raw: Variant = WorldState.get_value(_animal_state_key(instance_id), {})
	if not raw is Dictionary:
		return {}
	var state: Dictionary = (raw as Dictionary).duplicate(true)
	var current_day := maxi(WorldClock.day, 1)
	if state.has("happiness"):
		state["happiness"] = clampi(SaveValues.whole_number_or(state.get("happiness", 50), 50), 0, 100)
	for key: String in ["last_product_day", "last_pet_day", "last_fed_day"]:
		if state.has(key):
			# A malformed date should not grant free products/pets or punish the player
			# with a missed-feed state. Treat unparseable values as observed today.
			state[key] = clampi(SaveValues.whole_number_or(state.get(key, current_day), current_day), 0, current_day)
	if state.has("last_processed_day"):
		state["last_processed_day"] = clampi(SaveValues.whole_number_or(state.get("last_processed_day", current_day), current_day), 1, current_day)
	return state
