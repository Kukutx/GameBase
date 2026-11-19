class_name TouchButton
extends Control

## A round button of `TouchControls` that holds an input action pressed while
## a finger is on it, as a key would: the press and the release reach the game
## as `InputEventAction`s, so a handler that reads `event.is_action_pressed()`
## and one that polls `Input.is_action_pressed()` both see it. It shows the
## control's name, or a sign for the pause and back buttons.

## What the button shows.
enum Sign { NAME, PAUSE, BACK }

## The action it presses.
var action: StringName = &""
## The words on the button, already in the player's language.
var label := "":
	set(value):
		label = value
		queue_redraw()
var sign_shown := Sign.NAME:
	set(value):
		sign_shown = value
		queue_redraw()
var radius := 24.0:
	set(value):
		radius = value
		queue_redraw()

# The finger on the button (its touch index), or -1.
var _finger := -1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The button's center in the view.
func get_center() -> Vector2:
	return position + size * 0.5

## Whether a finger at `point` presses the button.
func reaches(point: Vector2) -> bool:
	return point.distance_to(get_center()) <= radius * 1.15

## Whether a finger holds the button down.
func is_held() -> bool:
	return _finger >= 0

## Finger `index` pressed the button.
func press(index: int, _point: Vector2) -> void:
	if is_held() or action.is_empty():
		return
	_finger = index
	_send(true)
	queue_redraw()

## Finger `index` moved; a button stays held until the finger lifts.
func drag(_index: int, _point: Vector2) -> void:
	pass

## Finger `index` lifted.
func lift(index: int) -> void:
	if index == _finger:
		release()

## Lets the action go, if the button held it.
func release() -> void:
	if not is_held():
		return
	_finger = -1
	_send(false)
	queue_redraw()

func _send(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)

func _draw() -> void:
	var center := size * 0.5
	var alpha := 0.8 if is_held() else 0.5
	draw_circle(center, radius, Color(0.08, 0.08, 0.1, alpha * 0.75))
	draw_arc(center, radius, 0.0, TAU, 40, Color(1, 1, 1, alpha), maxf(radius * 0.07, 1.0), true)
	var ink := Color(1, 1, 1, minf(alpha + 0.25, 1.0))
	match sign_shown:
		Sign.PAUSE:
			var bar := Vector2(radius * 0.22, radius * 0.9)
			draw_rect(Rect2(center + Vector2(-radius * 0.34, -bar.y * 0.5), bar), ink)
			draw_rect(Rect2(center + Vector2(radius * 0.12, -bar.y * 0.5), bar), ink)
		Sign.BACK:
			var arm := radius * 0.38
			var width := maxf(radius * 0.14, 1.0)
			draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), ink, width, true)
			draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), ink, width, true)
		_:
			_draw_label(center, ink)

# The label, as large as fits the button's width, centered.
func _draw_label(center: Vector2, ink: Color) -> void:
	if label.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := maxi(roundi(radius * 0.55), 6)
	var room := radius * 1.7
	while font_size > 6 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5)
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(floori(font_size / 6.0), 1), Color(0, 0, 0, 0.6))
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
