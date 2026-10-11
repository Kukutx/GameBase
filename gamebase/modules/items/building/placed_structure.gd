class_name PlacedStructure
extends Node2D

var placement_id: StringName
var placeable_id: StringName
var location_id: StringName

func configure_from_record(record: Dictionary) -> void:
	placement_id = StringName(String(record.get("id", "")))
	placeable_id = StringName(String(record.get("placeable_id", "")))
	location_id = StringName(String(record.get("location_id", "")))
	global_position = Vector2(float(record.get("x", 0.0)), float(record.get("y", 0.0)))

func get_placeable_data() -> PlaceableData:
	return PlaceableData.find(placeable_id)
