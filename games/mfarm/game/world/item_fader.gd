extends Node2D

## Fades a sprite (a tree top, a roof) while the player stands behind it, so
## the player stays in sight. The trigger is an `Area2D` of its own, or of its
## parent's.

const FADED_ALPHA := 0.45
const FADE_SECONDS := 0.35

var _tween: Tween

func _ready() -> void:
	var area := _find_area()
	if area == null:
		return
	area.collision_mask |= 2
	area.body_entered.connect(_on_body.bind(true))
	area.body_exited.connect(_on_body.bind(false))

func _on_body(body: Node2D, entered: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", FADED_ALPHA if entered else 1.0, FADE_SECONDS)

func _find_area() -> Area2D:
	for child: Node in get_children():
		if child is Area2D:
			return child
	var parent := get_parent()
	if parent != null:
		for child: Node in parent.get_children():
			if child is Area2D:
				return child
	return null
