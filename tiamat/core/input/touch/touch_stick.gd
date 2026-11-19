class_name TouchStick
extends Control

## The stick of `TouchControls`: a ring at the lower left that a finger drags
## a knob in, which walks the player as the move controls do. The knob's
## offset from the ring's center, up to the ring's edge, presses each move
## action as far as it points that way (`Input.action_press()` with a
## strength), so `Input.get_vector()` reads it as it reads a gamepad's stick.
## A finger anywhere in reach of the ring (`REACH` times its radius) takes it.

## The actions pushed toward the left, right, up and down.
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
## How far from the ring's center a finger may land and take the stick, in
## radii.
const REACH := 1.5
## The part of the radius the knob moves before the stick walks.
const DEAD_ZONE := 0.2

## The ring's radius, in pixels of the view.
var radius := 32.0:
	set(value):
		radius = value
		queue_redraw()

# The finger on the stick (its touch index), or -1.
var _finger := -1
# Where the knob is, from the center, up to `radius` away.
var _knob := Vector2.ZERO
# The move actions the stick holds pressed.
var _pressed: Dictionary[StringName, bool] = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The stick's center in the view.
func get_center() -> Vector2:
	return position + size * 0.5

## Whether a finger at `point` takes the stick.
func reaches(point: Vector2) -> bool:
	return point.distance_to(get_center()) <= radius * REACH

## Whether a finger holds the stick.
func is_held() -> bool:
	return _finger >= 0

## Where the stick points: zero inside the dead zone, else up to length 1.
func get_vector() -> Vector2:
	var length := _knob.length() / radius
	if length <= DEAD_ZONE:
		return Vector2.ZERO
	return _knob.normalized() * minf((length - DEAD_ZONE) / (1.0 - DEAD_ZONE), 1.0)

## Finger `index` landed at `point`: the stick follows it.
func press(index: int, point: Vector2) -> void:
	_finger = index
	drag(index, point)

## Finger `index` moved to `point`.
func drag(index: int, point: Vector2) -> void:
	if index != _finger:
		return
	_knob = (point - get_center()).limit_length(radius)
	_apply()
	queue_redraw()

## Finger `index` lifted: the stick lets go if it held it.
func lift(index: int) -> void:
	if index == _finger:
		release()

## Lets go: the knob goes back to the center and the moves are released.
func release() -> void:
	_finger = -1
	_knob = Vector2.ZERO
	_apply()
	queue_redraw()

func _apply() -> void:
	var vector := get_vector()
	var strengths := [maxf(-vector.x, 0.0), maxf(vector.x, 0.0), maxf(-vector.y, 0.0), maxf(vector.y, 0.0)]
	for index: int in MOVE_ACTIONS.size():
		var action := MOVE_ACTIONS[index]
		if not InputMap.has_action(action):
			continue
		if strengths[index] > 0.0:
			Input.action_press(action, strengths[index])
			_pressed[action] = true
		elif _pressed.has(action):
			# Only what the stick pressed: a key held at the same time stays.
			Input.action_release(action)
			_pressed.erase(action)

func _draw() -> void:
	var center := size * 0.5
	var alpha := 0.55 if is_held() else 0.35
	draw_circle(center, radius, Color(0.08, 0.08, 0.1, alpha * 0.6))
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, alpha), maxf(radius * 0.06, 1.0), true)
	draw_circle(center + _knob, radius * 0.45, Color(1, 1, 1, alpha + 0.15))
