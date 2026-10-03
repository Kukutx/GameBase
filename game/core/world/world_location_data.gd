class_name WorldLocationData
extends Resource

enum LocationType {
	TOWN,
	INTERIOR,
	WILDERNESS,
	DUNGEON,
}

@export var id: StringName
@export var display_name: String
@export_file("*.tscn") var scene_path: String
@export var type: LocationType = LocationType.TOWN
@export var weather_exposed := true
@export var default_spawn_id: StringName
@export var music_cue_id: StringName
