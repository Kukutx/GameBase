class_name KeyboardLift
extends RefCounted

## A phone's keyboard comes up over the game when the player types (a name, an
## amount): the menu of the field typed in (the `CanvasLayer` it draws on)
## rises until the field shows above the keyboard, no higher than takes the
## field's top to the window's, and goes back down when the keyboard goes or
## the field loses the focus. `TouchControls` follows the keyboard with one
## each frame (`follow()`).

## How far above the keyboard the field typed in shows, in the window's
## pixels.
const GAP := 12.0

# The layer raised over the keyboard, and where it sat before.
var _lifted: CanvasLayer = null
var _lifted_from := Vector2.ZERO

## How tall the keyboard on the screen is, in the window's pixels: 0 while it
## is down, or where the platform tells nothing (a computer; a browser, which
## does not say).
static func keyboard_height() -> int:
	if OS.has_feature("web") or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0
	return DisplayServer.virtual_keyboard_get_height()

## The text field the player types in on `viewport`, or null.
static func typing_field(viewport: Viewport) -> Control:
	var focused := viewport.gui_get_focus_owner()
	return focused if focused is LineEdit or focused is TextEdit else null

## Lifts the field typed in on `viewport` over the keyboard on the screen.
func follow(viewport: Viewport) -> void:
	lift(viewport, keyboard_height() if typing_field(viewport) != null else 0)

## Raises the menu of the field typed in on `viewport` so the field shows
## above a keyboard `keyboard` window pixels tall; sets it back down once the
## keyboard is gone (0) or no field is typed in.
func lift(viewport: Viewport, keyboard: int) -> void:
	var field := typing_field(viewport)
	var layer: CanvasLayer = field.get_canvas_layer_node() if keyboard > 0 and field != null else null
	if layer != _lifted:
		if is_instance_valid(_lifted):
			_lifted.offset = _lifted_from
		_lifted = layer
		if layer != null:
			_lifted_from = layer.offset
	if layer == null:
		return
	# Where the field stands on the window with its layer down.
	var window := field.get_tree().root
	var to_window := window.get_final_transform()
	var down := Transform2D(0.0, Vector2(0.0, _lifted_from.y - layer.offset.y)) * layer.get_final_transform()
	var rect := to_window * (down * field.get_global_rect())
	var keyboard_top := float(window.size.y - keyboard)
	var rise := clampf(rect.end.y + GAP - keyboard_top, 0.0, maxf(rect.position.y, 0.0))
	layer.offset.y = _lifted_from.y - rise / to_window.get_scale().y
