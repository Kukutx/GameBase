class_name WorldSpawnPoint
extends Marker2D

@export var spawn_id: StringName

func _ready() -> void:
	add_to_group("world_spawn_point")
