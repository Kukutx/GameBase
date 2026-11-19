class_name HudSafeArea
extends Node

## Keeps a HUD clear of a phone's notch, punch-hole camera and rounded
## corners. A phone held sideways draws the game under its camera, at one end
## of the screen: each control the HUD's layer (this node's parent) holds
## moves in from the sides it keeps to, by as much of that side as the screen
## leaves unsafe (`TouchControls.safe_rect()`). A control anchored at the left
## moves right by the left strip, one at the right moves left by the right
## strip, a line across the screen draws in from both, and the same from the
## top and the bottom; what sits in the middle, and what fills the whole view
## (a menu's backdrop, a weather overlay), stays where it is. A phone turned
## over moves its camera to the other end, and the HUD follows. A line's
## `TouchClearance` measures again after it moved.
##
## Add one as a child of a HUD's `CanvasLayer`, drawn at the view's scale. It
## moves nothing on a computer or in a browser, whose window is all clear.

## How often, in seconds, a phone's clear part is checked: a phone turned over
## keeps its size but moves its camera to the other side.
const CHECK_SECONDS := 0.5

# Control -> how far it moved (left, top, right and bottom offsets).
var _moved: Dictionary[Control, Vector4] = {}
var _safe := Rect2()
var _check_in := 0.0

func _ready() -> void:
	get_viewport().size_changed.connect(_refresh)
	set_process(OS.has_feature("mobile"))
	_refresh.call_deferred()

func _exit_tree() -> void:
	fit_to(Rect2())

func _process(delta: float) -> void:
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = CHECK_SECONDS
		_refresh()

## Moves the controls the layer holds into `safe`, a part of the view, from
## where they were laid out; the whole view (or an empty rect) puts them back.
func fit_to(safe: Rect2) -> void:
	var view := get_viewport().get_visible_rect() if is_inside_tree() else Rect2()
	var inset := Vector4.ZERO
	if safe.has_area() and view.has_area():
		inset = Vector4(maxf(safe.position.x - view.position.x, 0.0), maxf(safe.position.y - view.position.y, 0.0),
			maxf(view.end.x - safe.end.x, 0.0), maxf(view.end.y - safe.end.y, 0.0))
	_safe = safe
	for control: Control in _moved.keys():
		if not is_instance_valid(control) or control.get_parent() != get_parent():
			_moved.erase(control)
	var holder := get_parent()
	if holder == null:
		return
	for child: Node in holder.get_children():
		var control := child as Control
		if control == null or _fills_view(control):
			continue
		var shift := Vector4(_shift(control.anchor_left, inset.x, inset.z), _shift(control.anchor_top, inset.y, inset.w),
			_shift(control.anchor_right, inset.x, inset.z), _shift(control.anchor_bottom, inset.y, inset.w))
		var before: Vector4 = _moved.get(control, Vector4.ZERO)
		if shift == before:
			continue
		control.offset_left += shift.x - before.x
		control.offset_top += shift.y - before.y
		control.offset_right += shift.z - before.z
		control.offset_bottom += shift.w - before.w
		if shift == Vector4.ZERO:
			_moved.erase(control)
		else:
			_moved[control] = shift
		for clearance: Node in control.get_children():
			if clearance is TouchClearance:
				(clearance as TouchClearance).refresh()

## How far `control` moved in from where it was laid out (left, top, right and
## bottom offsets); zero where the screen is all clear.
func get_moved(control: Control) -> Vector4:
	return _moved.get(control, Vector4.ZERO)

func _refresh() -> void:
	if not is_inside_tree():
		return
	var safe := TouchControls.safe_rect() if OS.has_feature("mobile") else get_viewport().get_visible_rect()
	if safe != _safe:
		fit_to(safe)

# How far an offset at `anchor` moves: in from the start side, back from the
# end side, not at all in the middle.
static func _shift(anchor: float, start: float, end: float) -> float:
	if anchor < 0.5:
		return start
	if anchor > 0.5:
		return -end
	return 0.0

static func _fills_view(control: Control) -> bool:
	return is_zero_approx(control.anchor_left) and is_zero_approx(control.anchor_top) \
		and is_equal_approx(control.anchor_right, 1.0) and is_equal_approx(control.anchor_bottom, 1.0)
