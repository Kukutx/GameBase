class_name PlaceableData
extends ContentEntry

const KIND := &"placeable"

@export var display_name: String
@export var item_id: StringName
@export_file("*.tscn") var scene_path: String
@export var grid_size := Vector2i(1, 1)
@export_range(8, 128, 1) var snap_size := 16
@export_range(0.0, 256.0, 1.0) var minimum_spacing := 20.0
@export var daily_effect: StringName
@export_range(0.0, 512.0, 1.0) var effect_radius := 0.0
@export var allowed_location_types: Array[WorldLocationData.LocationType] = []
@export var allowed_location_ids: Array[StringName] = []

## The placeable with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> PlaceableData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as PlaceableData

## The running game's placeables, sorted by id.
static func find_all() -> Array[PlaceableData]:
	var result: Array[PlaceableData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func is_allowed_in(location: WorldLocationData) -> bool:
	if location == null:
		return false
	if not allowed_location_ids.is_empty() and not allowed_location_ids.has(location.id):
		return false
	return allowed_location_types.is_empty() or allowed_location_types.has(location.type)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	var item := registry.get_entry(ItemData.KIND, item_id) as ItemData
	if item == null:
		problems.append("references unknown item '%s'" % item_id)
	elif not item.is_placeable() or item.placeable_id != id:
		problems.append("item '%s' is not a PLACEABLE item that names this placeable" % item_id)
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		problems.append("references missing scene '%s'" % scene_path)
	else:
		var scene := load(scene_path) as PackedScene
		var root: Node = scene.instantiate() if scene != null else null
		if not root is PlacedStructure:
			problems.append("scene '%s' root is not a PlacedStructure" % scene_path)
		else:
			problems.append_array(registry.find_scene_problems(root, null))
		if root != null:
			root.free()
	for location_id: StringName in allowed_location_ids:
		if not registry.has_entry(WorldLocationData.KIND, location_id):
			problems.append("references unknown location '%s'" % location_id)
	return problems
