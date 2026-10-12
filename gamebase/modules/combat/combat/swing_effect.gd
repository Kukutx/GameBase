class_name SwingEffect
extends Node2D

## The arc a melee swing draws for a moment where it reaches, turned the way
## the swing goes (`rotation`), fading out. `MeleeAttack` keeps them in a
## `NodePool`; `finished` tells it one is done.

signal finished(swing: SwingEffect)

const SECONDS := 0.14
## Half the arc's angle.
const HALF_ANGLE := PI / 3.0
const RADIUS := 14.0
const WIDTH := 3.0
const COLOR := Color(1.0, 0.95, 0.85)

var _fade: Tween

## Starts the swing over, as the pool takes it again.
func reuse() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	modulate.a = 1.0
	queue_redraw()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, SECONDS)
	_fade.tween_callback(finished.emit.bind(self))

func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, -HALF_ANGLE, HALF_ANGLE, 12, COLOR, WIDTH, true)
