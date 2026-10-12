extends Node2D

## A location root that adds its spawn point from code, which the scene's
## node list does not show (`test_content_registry.gd`).

func _init() -> void:
	var gate := WorldSpawnPoint.new()
	gate.name = "Gate"
	gate.spawn_id = &"gate"
	add_child(gate)
