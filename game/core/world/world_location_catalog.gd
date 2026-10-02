class_name WorldLocationCatalog
extends Node

func get_location(location_id: StringName) -> WorldLocationData:
	return ContentDB.get_location(location_id)

func get_all_locations() -> Array[WorldLocationData]:
	return ContentDB.get_all_locations()
