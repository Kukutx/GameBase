class_name PlaceableData
extends Resource

@export var id: StringName
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

func is_allowed_in(location: WorldLocationData) -> bool:
	if location == null:
		return false
	if not allowed_location_ids.is_empty() and not allowed_location_ids.has(location.id):
		return false
	return allowed_location_types.is_empty() or allowed_location_types.has(location.type)
