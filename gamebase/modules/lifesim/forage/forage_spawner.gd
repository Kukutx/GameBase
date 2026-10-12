class_name ForageSpawner
extends Node2D

const PICKUP_SCENE := preload("res://gamebase/modules/items/items/item_pickup.tscn")

@export var spawner_id: StringName
@export var location_id: StringName
@export var spawn_rect := Rect2(-120, -80, 240, 160)
@export_range(0, 32, 1) var spawn_count := 3

var _spawned: Array[WorldItemPickup] = []
var _active_day := 0

func _ready() -> void:
	WorldClock.day_changed.connect(_on_day_changed)
	if location_id == &"":
		var location := WorldLocationData.find_current(get_tree())
		if location != null:
			location_id = location.id
	_rebuild(WorldClock.day)

func generate_plan(day: int, target_location_id: StringName = &"") -> Array[Dictionary]:
	var resolved_location := target_location_id if target_location_id != &"" else location_id
	var season := GameCalendar.current().get_season_name(day)
	var eligible: Array[ForageEntryData] = []
	for entry: ForageEntryData in ForageEntryData.find_all():
		if entry != null and entry.is_available(resolved_location, season):
			eligible.append(entry)
	if eligible.is_empty() or spawn_count <= 0 or spawner_id == &"":
		return []

	var weights := PackedFloat64Array()
	for entry: ForageEntryData in eligible:
		weights.append(entry.weight)
	var rng := GameRandom.stream("forage:%d:%s:%s" % [maxi(day, 1), spawner_id, resolved_location])
	var result: Array[Dictionary] = []
	for index in range(spawn_count):
		var picked := rng.pick_weighted(weights)
		if picked < 0:
			continue
		var entry := eligible[picked]
		result.append({
			"index": index,
			"item_id": String(entry.item_id),
			"quantity": roundi(GameStats.apply(&"forage_quantity", entry.get_quantity(rng))),
			"position": rng.point_in(spawn_rect),
		})
	return result

func get_spawned_pickups() -> Array[WorldItemPickup]:
	return _spawned.filter(func(pickup: WorldItemPickup) -> bool: return is_instance_valid(pickup))

func _on_day_changed(day: int) -> void:
	_rebuild(day)

func _rebuild(day: int) -> void:
	for pickup: WorldItemPickup in _spawned:
		if is_instance_valid(pickup):
			pickup.queue_free()
	_spawned.clear()
	_active_day = day
	var state := _get_state()
	if int(state["day"]) != day:
		state = {"day": day, "left": {}}
		_set_state(state)
	var left: Dictionary = state["left"]
	for spawn: Dictionary in generate_plan(day):
		var index := int(spawn["index"])
		var quantity := mini(int(left.get(str(index), spawn["quantity"])), int(spawn["quantity"]))
		if quantity <= 0:
			continue
		var item := ItemData.find(StringName(String(spawn["item_id"])))
		if item == null:
			continue
		var pickup := PICKUP_SCENE.instantiate() as WorldItemPickup
		pickup.name = "Forage_%02d_%s" % [index, String(item.id)]
		pickup.item = item
		pickup.quantity = quantity
		pickup.persistent_id = &""
		pickup.position = spawn["position"] as Vector2
		pickup.items_collected.connect(_on_pickup_collected.bind(index))
		add_child(pickup)
		_spawned.append(pickup)

# Keeps what is left of the spawn `index` today, so leaving and coming back
# never fills it up again.
func _on_pickup_collected(_item_id: StringName, _collected: int, remaining: int, index: int) -> void:
	var state := _get_state()
	if int(state["day"]) != _active_day:
		return
	(state["left"] as Dictionary)[str(index)] = maxi(remaining, 0)
	_set_state(state)

# {"day", "left"}: the day the spawns belong to and what is left of each.
func _get_state() -> Dictionary:
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if not raw is Dictionary:
		return {"day": 0, "left": {}}
	var source: Dictionary = raw
	var day := SaveValues.count(source.get("day", 0))
	# Spawn index (as text) -> what is left of it today.
	var left := {}
	var raw_left: Variant = source.get("left", {})
	if raw_left is Dictionary:
		for raw_index: Variant in raw_left.keys():
			var index := String(raw_index)
			var quantity: Variant = SaveValues.whole_number(raw_left[raw_index])
			if index.is_valid_int() and index.to_int() >= 0 and quantity != null and int(quantity) >= 0:
				left[str(index.to_int())] = int(quantity)
	return {"day": day, "left": left}

func _set_state(state: Dictionary) -> void:
	WorldState.set_value(_state_key(), state.duplicate(true))

func _state_key() -> StringName:
	return StringName("forage:%s" % String(spawner_id))

## The world state the spawner saves, for `ContentRegistry`'s check that no two
## nodes share it.
func get_persistent_keys() -> PackedStringArray:
	return PackedStringArray([String(_state_key())]) if spawner_id != &"" else PackedStringArray()

func find_scene_problems(_registry: ContentRegistry, location: WorldLocationData) -> PackedStringArray:
	var problems := PackedStringArray()
	if spawner_id == &"":
		problems.append("forage spawner '%s' has no spawner id" % name)
	if location != null and location_id != &"" and location_id != location.id:
		problems.append("forage spawner '%s' references different location '%s'" % [name, location_id])
	return problems
