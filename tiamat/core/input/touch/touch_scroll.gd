class_name TouchScroll
extends RefCounted

## A list (a `ScrollContainer`) on a touchscreen scrolls under the finger that
## drags it, wherever the drag starts: on a row's button, its panel or its
## picture as on the gaps between them. A tap on a button still presses it;
## a drag past a short way (`DEADZONE_MM`) scrolls the list and lets go of the
## button instead, as a phone's lists do.
##
## The engine scrolls a list on a touchscreen only by the drags that reach
## it, and a button, a panel or a coloured rect keeps the drags that start on
## it (`MOUSE_FILTER_STOP`). So in a list each such control passes them on
## (`MOUSE_FILTER_PASS`) once it is in the tree, and the list keeps them
## (`MOUSE_FILTER_STOP`), so a tap in a list never reaches the game behind it.
## The controls a finger drags itself keep theirs: a slider, a scroll bar, a
## number or text field, a list of its own, a tree, a row of tabs, a nested
## list, and text the player selects.
##
## `TouchControls` has every list adopted (`watch()`) on a device played by
## touch.

## How far a finger moves on a button before the list scrolls, in
## millimetres: a tap's wobble stays a tap.
const DEADZONE_MM := 2.0
## The deadzone, in the view's pixels, where the screen tells nothing.
const DEFAULT_DEADZONE := 8

## Has every list in `tree`, and every control added to one later, adopted
## (`adopt()`); with `on` false, stops (the lists adopted stay so).
static func watch(tree: SceneTree, on := true) -> void:
	if not on:
		if tree.node_added.is_connected(_on_node_added):
			tree.node_added.disconnect(_on_node_added)
		return
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	for node: Node in tree.root.find_children("*", "ScrollContainer", true, false):
		adopt(node as ScrollContainer)

## Has `control` pass the drags that start on it to the list it is in, and the
## list keep them; with `control` a list, every control in it. Nothing where
## it is in no list or is dragged itself (`is_dragged()`).
static func adopt(control: Control) -> void:
	if control is ScrollContainer:
		_adopt_list(control as ScrollContainer)
		for node: Node in control.find_children("*", "Control", true, false):
			adopt(node as Control)
	var list := list_of(control)
	if list == null or is_dragged(control):
		return
	_adopt_list(list)
	if control.mouse_filter == Control.MOUSE_FILTER_STOP:
		control.mouse_filter = Control.MOUSE_FILTER_PASS

## The list `control` is a row or a part of a row of, or null: its nearest
## `ScrollContainer` up to its canvas, not counting the list's own scroll bars.
static func list_of(control: Control) -> ScrollContainer:
	var child: Node = control
	var parent := control.get_parent()
	while parent != null and not (parent is Viewport or parent is CanvasLayer):
		if parent is ScrollContainer:
			return parent as ScrollContainer if parent.get_children().has(child) else null
		if child is CanvasItem and (child as CanvasItem).top_level:
			return null
		child = parent
		parent = parent.get_parent()
	return null

## Whether a finger drags `control` itself, so the drags that start on it stay
## its own.
static func is_dragged(control: Control) -> bool:
	if control is RichTextLabel:
		return (control as RichTextLabel).selection_enabled
	return control is Slider or control is ScrollBar or control is SpinBox or control is LineEdit \
			or control is TextEdit or control is ItemList or control is Tree or control is TabBar \
			or control is ScrollContainer or control is GraphEdit

## The deadzone of a list, in its own pixels, for a fingertip of `reach` view
## pixels (`TouchTarget.reach`; 0 where unknown) and a list drawn `scale`
## view pixels to its own.
static func deadzone(reach: float, scale: float) -> int:
	if reach <= 0.0 or scale <= 0.0:
		return DEFAULT_DEADZONE
	return maxi(roundi(reach * DEADZONE_MM / TouchTarget.FINGERTIP_MM / scale), 1)

static func _adopt_list(list: ScrollContainer) -> void:
	list.mouse_filter = Control.MOUSE_FILTER_STOP
	var scale := list.get_global_transform_with_canvas().get_scale().y if list.is_inside_tree() else 1.0
	list.scroll_deadzone = maxi(list.scroll_deadzone, deadzone(TouchTarget.reach, scale))

static func _on_node_added(node: Node) -> void:
	if node is Control:
		# Once it is ready: its own _ready may set how it takes the mouse.
		_adopt_later.call_deferred(node.get_instance_id())

static func _adopt_later(id: int) -> void:
	var control := instance_from_id(id) as Control
	if control != null and control.is_inside_tree():
		adopt(control)
