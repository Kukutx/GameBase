class_name ForageEntryData
extends Resource

@export var id: StringName
@export var item_id: StringName
@export var locations: Array[StringName] = []
@export var seasons: PackedStringArray = []
@export_range(0.01, 100.0, 0.01) var weight := 1.0
@export_range(1, 99, 1) var min_quantity := 1
@export_range(1, 99, 1) var max_quantity := 1

func is_available(location_id: StringName, season_name: String) -> bool:
	if not locations.is_empty() and not locations.has(location_id):
		return false
	if not seasons.is_empty() and not seasons.has(season_name):
		return false
	return item_id != &"" and weight > 0.0

func get_quantity(rng: RandomNumberGenerator) -> int:
	var minimum := mini(min_quantity, max_quantity)
	var maximum := maxi(min_quantity, max_quantity)
	return rng.randi_range(minimum, maximum)
