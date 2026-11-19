class_name TouchTarget
extends Control

## The reach of a button on a touchscreen: an invisible part of the button (an
## internal child) that takes the taps landing just beside it, so a button
## smaller than a fingertip (`FINGERTIP_MM`) answers a finger anywhere in a
## fingertip-sized square around its middle. Such a tap reaches the button as
## if it fell on the button's nearest edge: the button lights up, presses and
## takes the focus as it does under the finger.
##
## A reach takes no tap:
## - while the player is not playing by touch (`InputPrompts.using_touch`),
##   or while `reach` is 0;
## - while its button is hidden, disabled or lets the mouse through;
## - on the button itself, which takes those taps as before;
## - on another control the player works on the same canvas (`track()`), nor
##   nearer another button's edge than its own.
##
## On a device played by touch, `TouchControls` has every button given one
## (`watch()`) and keeps `reach` to a fingertip on the screen (`measure()`).

## A fingertip, in millimetres: the size the platforms ask of a tap target
## (Apple's 44 points, Android's 48 density pixels).
const FINGERTIP_MM := 7.0
## The most a fingertip is of the view's height, whatever the screen says of
## its pixels.
const MAX_REACH := 0.15

## The size of a fingertip in the view's pixels: how wide and tall the square
## a button smaller than that answers taps in is. 0 turns every reach off.
static var reach := 0.0
# The instance ids of the controls a tap may be meant for (`track()`).
static var _tracked: Dictionary[int, bool] = {}
# How many were tracked when the gone ones were last dropped.
static var _tracked_after_drop := 0

## A fingertip in the view's pixels, on a screen of `dpi` dots per inch that
## shows each pixel of a view `view_height` tall as `window_per_view` of its
## own (the window's stretch).
static func fingertip(dpi: float, window_per_view: float, view_height: float) -> float:
	if dpi <= 0.0 or window_per_view <= 0.0:
		return 0.0
	return minf(FINGERTIP_MM / 25.4 * dpi / window_per_view, view_height * MAX_REACH)

## Gives every button in `tree`, and each one added to it later, a reach,
## and tracks the controls a tap may be meant for (`track()`); with `on`
## false, stops (the reaches given stay, and take taps while `reach` is above
## 0).
static func watch(tree: SceneTree, on := true) -> void:
	if not on:
		if tree.node_added.is_connected(_on_node_added):
			tree.node_added.disconnect(_on_node_added)
		return
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	for node: Node in tree.root.find_children("*", "Control", true, false):
		_on_node_added(node)

## Sets `reach` to a fingertip on the screen `viewport` shows on.
static func measure(viewport: Viewport) -> void:
	reach = fingertip(DisplayServer.screen_get_dpi(), viewport.get_final_transform().get_scale().y, viewport.get_visible_rect().size.y)

## Gives `button` a reach, unless it has one, and tracks it.
static func attach(button: BaseButton) -> void:
	track(button)
	for child: Node in button.get_children(true):
		if child is TouchTarget:
			return
	var target := TouchTarget.new()
	target.name = "TouchTarget"
	button.add_child(target, false, Node.INTERNAL_MODE_BACK)

## The reach of `button`, or null.
static func of(button: BaseButton) -> TouchTarget:
	for child: Node in button.get_children(true):
		if child is TouchTarget:
			return child
	return null

## Whether a tap on `node` may be meant for it: a button, a slider or a scroll
## bar, a number or text field, a list, a tree or a row of tabs. A reach takes
## no tap that lands on one.
static func is_worked(node: Node) -> bool:
	return node is BaseButton or node is Slider or node is ScrollBar or node is SpinBox or node is LineEdit \
			or node is TextEdit or node is ItemList or node is Tree or node is TabBar

## Keeps `control` among the controls a reach takes no tap from (as long as it
## lives; one that leaves the tree and comes back stays tracked).
static func track(control: Control) -> void:
	_tracked[control.get_instance_id()] = true
	if _tracked.size() > _tracked_after_drop * 2 + 64:
		for id: int in _tracked.keys():
			if not is_instance_id_valid(id):
				_tracked.erase(id)
		_tracked_after_drop = _tracked.size()

## Where `button` answers taps, in its own coordinates: its rect, grown evenly
## to `reach` on each side it is smaller than that.
static func area_of(button: Control) -> Rect2:
	var own := Rect2(Vector2.ZERO, button.size)
	var scale := button.get_global_transform_with_canvas().get_scale().abs()
	if reach <= 0.0 or scale.x <= 0.0 or scale.y <= 0.0:
		return own
	var grow := ((Vector2(reach / scale.x, reach / scale.y) - button.size) * 0.5).max(Vector2.ZERO)
	return own.grow_individual(grow.x, grow.y, grow.x, grow.y)

static func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		# Once the button is in: its parent may be busy adding it.
		_attach_to.call_deferred(node.get_instance_id())
	elif is_worked(node):
		track(node)

static func _attach_to(id: int) -> void:
	var button := instance_from_id(id) as BaseButton
	if button != null and button.is_inside_tree():
		attach(button)

func _init() -> void:
	# The button's part: what it does not take goes on to the button.
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE

func _has_point(point: Vector2) -> bool:
	var button := get_parent() as BaseButton
	if reach <= 0.0 or button == null or not InputPrompts.using_touch:
		return false
	if button.disabled or button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	var own := Rect2(Vector2.ZERO, button.size)
	if own.has_point(point) or not area_of(button).has_point(point):
		return false
	var to_view := button.get_global_transform_with_canvas()
	var at := to_view * point
	return not _claimed_by_other(button, at, _distance(to_view * own, at))

# A tap here is the button's: on the button's nearest edge, where the button
# reads it as its own. One that slides off the reach leaves the button.
func _gui_input(event: InputEvent) -> void:
	var button := get_parent() as Control
	if button == null:
		return
	var pointer := event as InputEventMouse
	if pointer != null:
		if pointer is InputEventMouseButton or area_of(button).has_point(pointer.position):
			pointer.position = _onto(button, pointer.position)
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		touch.position = _onto(button, touch.position)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and area_of(button).has_point(drag.position):
		drag.position = _onto(button, drag.position)

# The point of `button` nearest `point`, just inside its edge.
static func _onto(button: Control, point: Vector2) -> Vector2:
	var edge := (button.size * 0.25).min(Vector2.ONE)
	return point.clamp(edge, (button.size - edge).max(edge))

# Whether a tap at `at`, in the view, `distance` from the button, is another
# control's: it lands on one on the same canvas, or nearer another button.
static func _claimed_by_other(button: BaseButton, at: Vector2, distance: float) -> bool:
	var canvas := button.get_canvas()
	for id: int in _tracked.keys():
		var other := instance_from_id(id) as Control
		if other == null:
			_tracked.erase(id)
			continue
		if other == button or not other.is_inside_tree() or not other.is_visible_in_tree() or other.mouse_filter == Control.MOUSE_FILTER_IGNORE or other.get_canvas() != canvas:
			continue
		var to_view := other.get_global_transform_with_canvas()
		var rect := to_view * Rect2(Vector2.ZERO, other.size)
		if rect.has_point(at):
			return true
		if other is BaseButton and not (other as BaseButton).disabled and _distance(rect, at) < distance:
			if (to_view * area_of(other)).has_point(at):
				return true
	return false

# How far `point` is from `rect`; 0 inside it.
static func _distance(rect: Rect2, point: Vector2) -> float:
	var out := Vector2(maxf(maxf(rect.position.x - point.x, point.x - rect.end.x), 0.0),
			maxf(maxf(rect.position.y - point.y, point.y - rect.end.y), 0.0))
	return out.length()
