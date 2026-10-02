class_name BuildZone
extends Area2D

@export var allowed_placeable_ids: Array[StringName] = []

func _ready() -> void:
	add_to_group("build_zone")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0

func allows(placeable_id: StringName) -> bool:
	return allowed_placeable_ids.is_empty() or allowed_placeable_ids.has(placeable_id)

func contains_global_point(point: Vector2) -> bool:
	for child: Node in get_children():
		var collision := child as CollisionShape2D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var local_point := collision.to_local(point)
		var shape := collision.shape
		if shape is RectangleShape2D:
			var half := (shape as RectangleShape2D).size * 0.5
			if absf(local_point.x) <= half.x and absf(local_point.y) <= half.y:
				return true
		elif shape is CircleShape2D:
			if local_point.length() <= (shape as CircleShape2D).radius:
				return true
	return false
