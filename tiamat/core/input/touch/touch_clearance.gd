class_name TouchClearance
extends Node

## Keeps its parent, a HUD control placed by its anchors and offsets (not by a
## container), clear of the touch controls (`TouchControls`): while they show,
## the side of the parent that a control covers draws back to that control's
## edge, the left side from the stick, the right side from the buttons, so the
## HUD's text never sits under a thumb. The parent goes back to where it was
## when they hide. A line that clips its text (`Label.clip_text`) then shows
## what fits between them; a line that does not keeps the width its text
## needs.
##
## Add one as the child of each HUD line near the bottom of the screen; it
## does nothing while the player plays with keys, a mouse or a gamepad. It
## moves the line by how much it draws back, so the line may be moved by
## others meanwhile (`HudSafeArea`), who call `refresh()` after.

var _parent: Control
# How far, in the parent's offsets, each side drew back, while drawn back.
var _left := 0.0
var _right := 0.0
var _drawn_back := false
# Whether this node is moving the parent, whose resize is then its own.
var _moving := false

func _ready() -> void:
	_parent = get_parent() as Control
	if _parent == null:
		push_warning("TouchClearance %s: its parent is no Control" % get_path())
		return
	TouchControls.layout_changed.connect(_update)
	_parent.resized.connect(_on_parent_resized)
	_update.call_deferred()

func _exit_tree() -> void:
	_restore()

## How far, in the view, each side of the parent drew back: x the left, y the
## right; zero while nothing covers it.
func get_drawn_back() -> Vector2:
	if not _drawn_back:
		return Vector2.ZERO
	return Vector2(_left, _right) * _view_factor()

## Measures the line again where it now is, as after anyone moved it.
func refresh() -> void:
	_update()

func _update() -> void:
	if _parent == null or not is_inside_tree():
		return
	_restore()
	var rect := _view_rect()
	var left := rect.position.x
	var right := rect.end.x
	for covered: Rect2 in TouchControls.get_covered_rects():
		if not covered.intersects(rect):
			continue
		if covered.get_center().x < rect.get_center().x:
			left = maxf(left, covered.end.x)
		else:
			right = minf(right, covered.position.x)
	if left == rect.position.x and right == rect.end.x:
		return
	right = maxf(right, left)
	var factor := _view_factor()
	if factor <= 0.0:
		return
	_left = (left - rect.position.x) / factor
	_right = (rect.end.x - right) / factor
	_drawn_back = true
	_moving = true
	_parent.offset_left += _left
	_parent.offset_right -= _right
	_moving = false

func _restore() -> void:
	if not _drawn_back or _parent == null:
		return
	_drawn_back = false
	_moving = true
	_parent.offset_left -= _left
	_parent.offset_right += _right
	_moving = false

# A resize the game made (not this node) moves the line: measure it again.
func _on_parent_resized() -> void:
	if not _moving and not _drawn_back:
		_update.call_deferred()

# The parent's rect in the view, as the touch controls' are.
func _view_rect() -> Rect2:
	return _parent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _parent.size)

# How many of the view's pixels one unit of the parent's offsets spans.
func _view_factor() -> float:
	var own := _parent.scale.x
	if is_zero_approx(own):
		return 0.0
	return _parent.get_global_transform_with_canvas().get_scale().x / own
