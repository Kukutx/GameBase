class_name CropData
extends Resource

@export var id: StringName
@export var display_name: String
@export_range(1, 60, 1) var days_to_mature := 4
@export_range(0, 60, 1) var regrow_days := 0
@export var harvest_item_id: StringName
@export_range(1, 99, 1) var harvest_quantity := 1
@export var allowed_seasons: PackedStringArray = ["Spring", "Summer", "Autumn", "Winter"]
@export var sprout_color := Color(0.36, 0.68, 0.28, 1.0)
@export var mature_color := Color(0.52, 0.78, 0.32, 1.0)

func can_grow_in(season_name: String) -> bool:
	return allowed_seasons.is_empty() or allowed_seasons.has(season_name)
