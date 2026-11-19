class_name MFarmLocation
extends Node2D

## The root of an MFarm location's scene: names the location its nodes belong
## to and plays its ambient sound under the location's music.

@export var location_id: StringName
@export var ambient: AudioStream
@export_range(-40.0, 6.0, 0.1) var ambient_volume_db := -2.0

func _ready() -> void:
	add_to_group(&"mfarm_location")
	if ambient != null:
		var player := AudioStreamPlayer.new()
		player.name = "Ambient"
		player.stream = ambient
		player.volume_db = ambient_volume_db
		player.bus = &"Sounds"
		add_child(player)
		player.play()

## The id of the location whose scene holds `node`, or empty.
static func id_of(node: Node) -> StringName:
	var current := node
	while current != null:
		if current is MFarmLocation:
			return (current as MFarmLocation).location_id
		current = current.get_parent()
	return &""

## A key naming `node` within its location's scene, stable across loads.
static func key_of(node: Node) -> String:
	var current := node
	while current != null and not current is MFarmLocation:
		current = current.get_parent()
	return String(current.get_path_to(node)) if current != null else String(node.name)
