class_name BuildingPlacementService
extends Node

## The structures the player places in the world (`PlaceableData`, such as a
## chest, a furnace or a sprinkler): which stand where in each location, and
## whether a new one may go at a spot. Each time the scene changes it builds the
## current location's structures under a `PlacedStructures` node.
##
## The placements live in `WorldState` (`building:placements:<location id>`), so
## they are saved with the world and a new game has none. A spot is refused
## outside the scene's build zones (`BuildZone`, when it has any) or too close to
## another structure. Placing from the inventory uses up the structure's item,
## and packing it up gives the item back; packing up is refused while the item
## does not fit or the structure says it cannot be packed up (`can_pack_up()`).
## `placement_added` and `placement_removed` announce each change.

signal placement_added(location_id: StringName, record: Dictionary)
signal placement_removed(location_id: StringName, placement_id: StringName)

const SERIAL_KEY := &"building:serial"
const PLACEMENTS_PREFIX := "building:placements:"
const CONTAINER_NAME := "PlacedStructures"

var _removing_placements: Dictionary = {}
var _placing_from_inventory := false
# location id (String) -> {"source": the records WorldState holds, "revision":
# the content's, "records": them checked, "effects": effect -> positions}.
var _checked: Dictionary = {}

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	refresh_current_scene.call_deferred()

func get_placements(location_id: StringName) -> Array[Dictionary]:
	var records: Array[Dictionary] = _get_checked(location_id)["records"]
	return records.duplicate(true)

# The location's records, checked once for each value WorldState holds and
# each content; callers read them and never change them.
func _get_checked(location_id: StringName) -> Dictionary:
	var raw: Variant = WorldState.get_value(_placements_key(location_id), [])
	var cached: Dictionary = _checked.get(String(location_id), {})
	if not cached.is_empty() and is_same(cached["source"], raw) and int(cached["revision"]) == ContentRegistry.active.revision:
		return cached
	cached = {"source": raw, "revision": ContentRegistry.active.revision, "records": _check_records(location_id, raw), "effects": {}}
	_checked[String(location_id)] = cached
	return cached

func _check_records(location_id: StringName, raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	if raw is Array:
		for value: Variant in raw:
			if not value is Dictionary:
				continue
			var record := (value as Dictionary).duplicate(true)
			var placement_id := StringName(String(record.get("id", "")))
			var placeable_id := StringName(String(record.get("placeable_id", "")))
			var record_location := StringName(String(record.get("location_id", "")))
			var raw_x: Variant = record.get("x", null)
			var raw_y: Variant = record.get("y", null)
			# Malformed records and placeables that are not content are dropped, so
			# they cannot become invisible blockers or break placement maths.
			if placement_id == &"" or seen_ids.has(String(placement_id)):
				continue
			if placeable_id == &"" or PlaceableData.find(placeable_id) == null:
				continue
			if record_location != &"" and record_location != location_id:
				continue
			if not _is_numeric(raw_x) or not _is_numeric(raw_y):
				continue
			seen_ids[String(placement_id)] = true
			record["id"] = String(placement_id)
			record["placeable_id"] = String(placeable_id)
			record["location_id"] = String(location_id)
			record["x"] = float(raw_x)
			record["y"] = float(raw_y)
			result.append(record)
	return result

func can_place(placeable_id: StringName, location_id: StringName, position: Vector2) -> bool:
	var data := PlaceableData.find(placeable_id)
	var location := WorldLocationData.find(location_id)
	if data == null or location == null or not data.is_allowed_in(location):
		return false
	if data.scene_path.is_empty() or not ResourceLoader.exists(data.scene_path):
		return false
	var snapped := snap_position(position, data.snap_size)
	if _current_location_id() == location_id and not _is_inside_build_zone(placeable_id, snapped):
		return false
	for record: Dictionary in _get_checked(location_id)["records"]:
		var other_data := PlaceableData.find(StringName(String(record.get("placeable_id", ""))))
		var other_position := Vector2(float(record.get("x", 0.0)), float(record.get("y", 0.0)))
		var required_spacing := data.minimum_spacing
		if other_data != null:
			required_spacing = maxf(required_spacing, other_data.minimum_spacing)
		if snapped.distance_to(other_position) < required_spacing:
			return false
	return true

func place_from_inventory(placeable_id: StringName, location_id: StringName, position: Vector2) -> Dictionary:
	if _placing_from_inventory:
		return {}
	_placing_from_inventory = true
	var result := _place_from_inventory_internal(placeable_id, location_id, position)
	_placing_from_inventory = false
	return result

func _place_from_inventory_internal(placeable_id: StringName, location_id: StringName, position: Vector2) -> Dictionary:
	var data := PlaceableData.find(placeable_id)
	if data == null or data.item_id == &"" or not InventoryState.has_item(data.item_id, 1):
		return {}
	var record := place(placeable_id, location_id, position)
	if record.is_empty():
		return {}
	if not InventoryState.remove_item(data.item_id, 1):
		remove_placement(location_id, StringName(String(record["id"])), false)
		return {}
	return record

func place(placeable_id: StringName, location_id: StringName, position: Vector2) -> Dictionary:
	var data := PlaceableData.find(placeable_id)
	if data == null or not can_place(placeable_id, location_id, position):
		return {}
	var serial := _next_unique_serial()
	WorldState.set_value(SERIAL_KEY, serial)
	var snapped := snap_position(position, data.snap_size)
	var record := {
		"id": "placed_%06d" % serial,
		"placeable_id": String(placeable_id),
		"location_id": String(location_id),
		"x": snapped.x,
		"y": snapped.y,
	}
	var placements := get_placements(location_id)
	placements.append(record)
	_set_placements(location_id, placements)
	placement_added.emit(location_id, record.duplicate(true))
	if _current_location_id() == location_id:
		_spawn_record(record)
	return record

func remove_placement(location_id: StringName, placement_id: StringName, refund_item := true) -> bool:
	var placement_key := String(placement_id)
	if _removing_placements.has(placement_key):
		return false
	var placements := get_placements(location_id)
	var removed: Dictionary = {}
	var next: Array[Dictionary] = []
	for record: Dictionary in placements:
		if StringName(String(record.get("id", ""))) == placement_id:
			removed = record
		else:
			next.append(record)
	if removed.is_empty():
		return false
	var existing := get_tree().get_first_node_in_group("placed_structure_%s" % String(placement_id))
	if existing != null and existing.has_method("can_pack_up") and not bool(existing.call("can_pack_up")):
		return false
	var refund_data: PlaceableData = null
	if refund_item:
		refund_data = PlaceableData.find(StringName(String(removed.get("placeable_id", ""))))
		if refund_data != null and refund_data.item_id != &"" and not _refund_fits(refund_data.item_id):
			GameEvents.toast("Make room before packing up this structure")
			return false
	_removing_placements[placement_key] = true
	if refund_data != null and refund_data.item_id != &"":
		if not InventoryState.return_items_atomic({String(refund_data.item_id): 1}):
			_removing_placements.erase(placement_key)
			GameEvents.toast("Inventory changed before the structure could be packed up")
			return false
	if existing != null and existing.has_method("on_removed"):
		existing.call("on_removed")
	_set_placements(location_id, next)
	if existing != null:
		existing.queue_free()
	_removing_placements.erase(placement_key)
	placement_removed.emit(location_id, placement_id)
	return true

func get_daily_effect_positions(location_id: StringName, effect: StringName) -> Array[Dictionary]:
	return _get_effect_positions(location_id, effect).duplicate(true)

## Whether a placement with the daily `effect` covers `point`. Every farm plot
## asks each day, so the placements are checked once, not once per plot.
func is_point_affected(location_id: StringName, effect: StringName, point: Vector2) -> bool:
	for entry: Dictionary in _get_effect_positions(location_id, effect):
		if point.distance_to(entry["position"] as Vector2) <= float(entry["radius"]):
			return true
	return false

func _get_effect_positions(location_id: StringName, effect: StringName) -> Array[Dictionary]:
	var checked := _get_checked(location_id)
	var effects: Dictionary = checked["effects"]
	if effects.has(effect):
		return effects[effect]
	var result: Array[Dictionary] = []
	for record: Dictionary in checked["records"]:
		var data := PlaceableData.find(StringName(String(record.get("placeable_id", ""))))
		if data == null or data.daily_effect != effect:
			continue
		result.append({
			"position": Vector2(float(record.get("x", 0.0)), float(record.get("y", 0.0))),
			"radius": data.effect_radius,
			"placement_id": String(record.get("id", "")),
		})
	effects[effect] = result
	return result

func refresh_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var existing := scene.get_node_or_null(CONTAINER_NAME)
	if existing != null:
		scene.remove_child(existing)
		existing.queue_free()
	var container := Node2D.new()
	container.name = CONTAINER_NAME
	scene.add_child(container)
	var location_id := _current_location_id()
	if location_id == &"":
		return
	for record: Dictionary in get_placements(location_id):
		_spawn_record(record, container)

func snap_position(position: Vector2, snap_size: int) -> Vector2:
	var size := maxi(snap_size, 1)
	return Vector2(round(position.x / size) * size, round(position.y / size) * size)

func _spawn_record(record: Dictionary, explicit_parent: Node2D = null) -> Node2D:
	var data := PlaceableData.find(StringName(String(record.get("placeable_id", ""))))
	if data == null or data.scene_path.is_empty() or not ResourceLoader.exists(data.scene_path):
		return null
	var packed := load(data.scene_path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node2D
	if node == null:
		return null
	var parent := explicit_parent
	if parent == null:
		parent = _get_or_create_container()
	if parent == null:
		return null
	if node.has_method("configure_from_record"):
		node.call("configure_from_record", record)
	else:
		node.position = Vector2(float(record.get("x", 0.0)), float(record.get("y", 0.0)))
	parent.add_child(node)
	var placement_id := String(record.get("id", ""))
	if not placement_id.is_empty():
		node.add_to_group("placed_structure_%s" % placement_id)
	return node

func _get_or_create_container() -> Node2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var container := scene.get_node_or_null(CONTAINER_NAME) as Node2D
	if container == null:
		container = Node2D.new()
		container.name = CONTAINER_NAME
		scene.add_child(container)
	return container

func _current_location_id() -> StringName:
	var location := WorldLocationData.find_current(get_tree())
	return location.id if location != null else &""

func _is_inside_build_zone(placeable_id: StringName, point: Vector2) -> bool:
	var zones := get_tree().get_nodes_in_group("build_zone")
	if zones.is_empty():
		return true
	for raw_zone: Node in zones:
		var zone := raw_zone as BuildZone
		if zone != null and zone.allows(placeable_id) and zone.contains_global_point(point):
			return true
	return false

func _next_unique_serial() -> int:
	var used_ids: Dictionary = {}
	for key: StringName in WorldState.get_keys(PLACEMENTS_PREFIX):
		var raw_records: Variant = WorldState.get_value(key)
		if not raw_records is Array:
			continue
		for raw_record: Variant in raw_records:
			if raw_record is Dictionary:
				var placement_id := String((raw_record as Dictionary).get("id", ""))
				if not placement_id.is_empty():
					used_ids[placement_id] = true
	var serial := maxi(SaveValues.whole_number_or(WorldState.get_value(SERIAL_KEY, 0), 0) + 1, 1)
	while used_ids.has("placed_%06d" % serial):
		serial += 1
	return serial

func _refund_fits(item_id: StringName) -> bool:
	return InventoryState.can_add_item(ItemData.find(item_id), 1)

func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func _set_placements(location_id: StringName, placements: Array[Dictionary]) -> void:
	WorldState.set_value(_placements_key(location_id), placements.duplicate(true))

func _placements_key(location_id: StringName) -> StringName:
	return StringName(PLACEMENTS_PREFIX + String(location_id))

func _on_scene_changed() -> void:
	refresh_current_scene.call_deferred()
