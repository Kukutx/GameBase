extends GutTest

## A list on a touchscreen (`TouchScroll`): the buttons, panels and pictures
## of its rows pass the drags that start on them on to the list, which keeps
## them, while what a finger drags itself (a slider, a field, selectable text,
## a list of its own) and anything outside a list keep theirs; the list waits
## for a finger to move a short way before it scrolls; a tap on a row's button
## still presses it and goes no further than the list, and the list scrolling
## lets go of it; and watching the tree adopts the controls added to a list
## once they are ready.

# A button whose own _ready keeps the drags, as a game's might.
class KeepingButton extends Button:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

# Counts the clicks that reach the game behind the menus.
class Behind extends Node:
	var clicks := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			clicks += 1

var _layer: CanvasLayer
var _reach := 0.0
var _hidden: Array[CanvasLayer] = []

func before_each() -> void:
	# The reach of a fingertip on no screen in particular.
	_reach = TouchTarget.reach
	TouchTarget.reach = 0.0
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child_autofree(_layer)

func after_each() -> void:
	TouchScroll.watch(get_tree(), false)
	TouchTarget.reach = _reach
	for layer: CanvasLayer in _hidden:
		layer.visible = true
	_hidden.clear()

func test_a_list_s_rows_pass_the_drags_on_to_it() -> void:
	var panel := Panel.new()
	_layer.add_child(panel)
	var list := _list(panel)
	var rows := list.get_child(0)
	var button := Button.new()
	var row := PanelContainer.new()
	var row_button := Button.new()
	row.add_child(row_button)
	var picture := ColorRect.new()
	var slider := HSlider.new()
	var field := LineEdit.new()
	var label := Label.new()
	var text := RichTextLabel.new()
	var selectable := RichTextLabel.new()
	selectable.selection_enabled = true
	var inner := ScrollContainer.new()
	var inner_button := Button.new()
	inner.add_child(inner_button)
	for control: Control in [button, row, picture, slider, field, label, text, selectable, inner]:
		rows.add_child(control)
	var outside := Button.new()
	_layer.add_child(outside)
	TouchScroll.adopt(list)
	for control: Control in [button, row, row_button, picture, text, inner_button]:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_PASS, "%s passes the drags on" % control.get_class())
	for control: Control in [slider, field, selectable, inner]:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_STOP, "%s keeps its own" % control.get_class())
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "what took no drags takes none")
	assert_eq(list.mouse_filter, Control.MOUSE_FILTER_STOP, "the list keeps them")
	assert_eq(list.get_v_scroll_bar().mouse_filter, Control.MOUSE_FILTER_STOP, "and its scroll bar its own")
	assert_eq(list.scroll_deadzone, TouchScroll.DEFAULT_DEADZONE, "it waits for the finger to move")
	assert_eq(outside.mouse_filter, Control.MOUSE_FILTER_STOP, "a button in no list keeps its own")
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_STOP, "and so does what holds the list")

func test_the_deadzone_is_a_short_way_for_a_finger() -> void:
	assert_eq(TouchScroll.deadzone(70.0, 1.0), 20, "2 mm of a 7 mm fingertip")
	assert_eq(TouchScroll.deadzone(70.0, 2.0), 10, "in the list's own pixels")
	assert_eq(TouchScroll.deadzone(0.0, 1.0), TouchScroll.DEFAULT_DEADZONE, "a few pixels where the screen tells nothing")

func test_a_tap_on_a_row_s_button_presses_it_and_goes_no_further() -> void:
	_hide_layers_over_the_test()
	var behind := Behind.new()
	add_child_autofree(behind)
	var list := _list(_layer)
	var button := Button.new()
	button.custom_minimum_size = Vector2(80, 30)
	list.get_child(0).add_child(button)
	TouchScroll.adopt(list)
	await wait_process_frames(2)
	var presses: Array[bool] = []
	button.pressed.connect(func() -> void: presses.append(true))
	var at := button.get_global_rect().get_center()
	_click(at, true)
	_click(at, false)
	assert_eq(presses.size(), 1, "a tap presses it")
	assert_eq(behind.clicks, 0, "and reaches nothing behind the list")
	_click(at, true)
	list.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	_click(at, false)
	assert_eq(presses.size(), 1, "the list scrolling lets go of it")

func test_watching_adopts_what_a_list_is_given_once_it_is_ready() -> void:
	var list := _list(_layer)
	TouchScroll.watch(get_tree())
	assert_eq(list.mouse_filter, Control.MOUSE_FILTER_STOP, "a list in the tree is adopted at once")
	var button := KeepingButton.new()
	list.get_child(0).add_child(button)
	await get_tree().process_frame
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_PASS, "a button added passes the drags on, after its own _ready")
	TouchScroll.watch(get_tree(), false)
	var later := Button.new()
	list.get_child(0).add_child(later)
	await get_tree().process_frame
	assert_eq(later.mouse_filter, Control.MOUSE_FILTER_STOP, "none once the watch stops")

# A list of rows at the top left of `parent`.
func _list(parent: Node) -> ScrollContainer:
	var list := ScrollContainer.new()
	list.position = Vector2(20, 20)
	list.size = Vector2(160, 120)
	var rows := VBoxContainer.new()
	list.add_child(rows)
	parent.add_child(list)
	list.size = Vector2(160, 120)
	return list

func _hide_layers_over_the_test() -> void:
	for node: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if layer != _layer and layer.layer >= _layer.layer and layer.visible:
			layer.visible = false
			_hidden.append(layer)

func _click(at: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.device = InputEvent.DEVICE_ID_EMULATION
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.pressed = pressed
	click.position = get_tree().root.get_final_transform() * at
	click.global_position = click.position
	get_viewport().push_input(click)
