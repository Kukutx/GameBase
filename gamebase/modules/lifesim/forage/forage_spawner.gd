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
	var season := GameClock.get_season_name_for_day(day)
	var eligible: Array[ForageEntryData] = []
	for entry: ForageEntryData in ForageEntryData.find_all():
		if entry != null and entry.is_available(resolved_location, season):
			eligible.append(entry)
	if eligible.is_empty() or spawn_count <= 0 or spawner_id == &"":
		return []

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("forage:%d:%d:%s:%s" % [WeatherState.world_seed, maxi(day, 1), String(spawner_id), String(resolved_location)])
	var result: Array[Dictionary] = []
	for index in range(spawn_count):
		var entry := _weighted_pick(eligible, rng)
		if entry == null:
			continue
		result.append({
			"index": index,
			"item_id": String(entry.item_id),
			"quantity": roundi(GameStats.apply(&"forage_quantity", entry.get_quantity(rng))),
			"position": Vector2(
				rng.randf_range(spawn_rect.position.x, spawn_rect.end.x),
				rng.randf_range(spawn_rect.position.y, spawn_rect.end.y)
			),
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
	if int(state.get("day", 0)) != day:
		state = {"day": day, "collected": []}
		_set_state(state)
	var collected: Array = state.get("collected", []) if state.get("collected", []) is Array else []
	for spawn: Dictionary in generate_plan(day):
		var index := int(spawn["index"])
		if collected.has(index):
			continue
		var item := ItemData.find(StringName(String(spawn["item_id"])))
		if item == null:
			continue
		var pickup := PICKUP_SCENE.instantiate() as WorldItemPickup
		pickup.name = "Forage_%02d_%s" % [index, String(item.id)]
		pickup.item = item
		pickup.quantity = int(spawn["quantity"])
		pickup.persistent_id = &""
		pickup.position = spawn["position"] as Vector2
		pickup.fully_collected.connect(_on_pickup_collected.bind(index))
		add_child(pickup)
		_spawned.append(pickup)

func _on_pickup_collected(_item_id: StringName, index: int) -> void:
	var state := _get_state()
	if int(state.get("day", 0)) != _active_day:
		return
	var collected: Array = state.get("collected", []) if state.get("collected", []) is Array else []
	if not collected.has(index):
		collected.append(index)
		collected.sort()
	state["collected"] = collected
	_set_state(state)

func _weighted_pick(entries: Array[ForageEntryData], rng: RandomNumberGenerator) -> ForageEntryData:
	var total := 0.0
	for entry: ForageEntryData in entries:
		total += maxf(entry.weight, 0.0)
	if total <= 0.0:
		return null
	var roll := rng.randf_range(0.0, total)
	var cursor := 0.0
	for entry: ForageEntryData in entries:
		cursor += maxf(entry.weight, 0.0)
		if roll <= cursor:
			return entry
	return entries.back()

func _get_state() -> Dictionary:
	var raw: Variant = WorldState.get_value(_state_key(), {})
	if not raw is Dictionary:
		return {}
	var source: Dictionary = raw
	var raw_day: Variant = source.get("day", 0)
	var day := int(raw_day) if typeof(raw_day) == TYPE_INT or typeof(raw_day) == TYPE_FLOAT else 0
	var collected: Array[int] = []
	var raw_collected: Variant = source.get("collected", [])
	if raw_collected is Array:
		for raw_index: Variant in raw_collected:
			if typeof(raw_index) != TYPE_INT and typeof(raw_index) != TYPE_FLOAT:
				continue
			var index := int(raw_index)
			if index >= 0 and not collected.has(index):
				collected.append(index)
	collected.sort()
	return {"day": maxi(day, 0), "collected": collected}

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
