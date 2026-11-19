extends GutTest

## A button smaller than a fingertip on a touchscreen (`TouchTarget`): a
## fingertip is measured in the view's pixels; a small button answers taps in
## a fingertip-sized square around its middle, and a tap there presses it as
## one on it does, while a tap further off, one that slides away, one on
## another control or nearer another button's edge, one beside a disabled
## button and one while the player uses the mouse do not; and watching the
## tree gives every button added a reach the game does not see.

const REACH := 40.0

var _layer: CanvasLayer
var _reach := 0.0
# The layers over the test's, hidden while it taps (the test runner's own).
var _hidden: Array[CanvasLayer] = []

func before_each() -> void:
	_reach = TouchTarget.reach
	TouchTarget.reach = REACH
	InputPrompts.call("_set_using_touch", true)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child_autofree(_layer)

func after_each() -> void:
	TouchTarget.watch(get_tree(), false)
	TouchTarget.reach = _reach
	InputPrompts.call("_set_using_touch", false)
	for layer: CanvasLayer in _hidden:
		layer.visible = true
	_hidden.clear()

func test_a_fingertip_is_measured_in_the_view_s_pixels() -> void:
	assert_almost_eq(TouchTarget.fingertip(254.0, 1.0, 1000.0), 70.0, 0.01, "7 mm at 254 dots an inch")
	assert_almost_eq(TouchTarget.fingertip(254.0, 2.0, 1000.0), 35.0, 0.01, "half as many where the window shows each pixel as two")
	assert_almost_eq(TouchTarget.fingertip(2540.0, 1.0, 600.0), 90.0, 0.01, "no more than 15% of the view's height")
	assert_eq(TouchTarget.fingertip(0.0, 1.0, 600.0), 0.0, "nothing where the screen tells nothing")

func test_a_small_button_answers_taps_in_a_fingertip_around_it() -> void:
	var small := _button(Vector2(100, 100), Vector2(10, 10))
	var wide := _button(Vector2(100, 300), Vector2(80, 10))
	var big := _button(Vector2(300, 100), Vector2(80, 50))
	assert_eq(TouchTarget.area_of(small), Rect2(-15, -15, 40, 40), "a fingertip's square around its middle")
	assert_eq(TouchTarget.area_of(wide), Rect2(0, -15, 80, 40), "grown only where it is smaller")
	assert_eq(TouchTarget.area_of(big), Rect2(0, 0, 80, 50), "a big button keeps its own")
	var target := TouchTarget.of(small)
	assert_true(target._has_point(Vector2(-14, 5)), "beside it")
	assert_true(target._has_point(Vector2(5, 24)), "below it")
	assert_false(target._has_point(Vector2(-16, 5)), "not further than a fingertip's square")
	assert_false(target._has_point(Vector2(5, 5)), "the button takes the taps on itself")
	small.disabled = true
	assert_false(target._has_point(Vector2(-14, 5)), "nor beside a disabled button")
	small.disabled = false
	InputPrompts.call("_set_using_touch", false)
	assert_false(target._has_point(Vector2(-14, 5)), "nor while the player uses the mouse")
	InputPrompts.call("_set_using_touch", true)
	TouchTarget.reach = 0.0
	assert_false(target._has_point(Vector2(-14, 5)), "nor with the reach off")

func test_a_reach_takes_no_tap_meant_for_another_control() -> void:
	var left := TouchTarget.of(_button(Vector2(100, 100), Vector2(10, 10)))
	var right_button := _button(Vector2(120, 100), Vector2(10, 10))
	var right := TouchTarget.of(right_button)
	var field := LineEdit.new()
	field.position = Vector2(80, 120)
	_layer.add_child(field)
	field.size = Vector2(60, 30)
	TouchTarget.track(field)
	assert_true(left._has_point(Vector2(13, 5)), "between two buttons, the nearer takes it")
	assert_false(right._has_point(Vector2(-7, 5)), "not the further")
	assert_true(right._has_point(Vector2(-3, 5)))
	assert_false(left._has_point(Vector2(17, 5)))
	assert_false(left._has_point(Vector2(21, 5)), "not on the other button")
	assert_false(left._has_point(Vector2(5, 22)), "not on a text field")
	right_button.disabled = true
	assert_true(left._has_point(Vector2(17, 5)), "a disabled button competes for nothing")
	# A control of another layer, as a HUD under a menu, takes nothing.
	var other_layer := CanvasLayer.new()
	add_child_autofree(other_layer)
	var under := LineEdit.new()
	under.position = Vector2(90, 90)
	other_layer.add_child(under)
	TouchTarget.track(under)
	assert_true(left._has_point(Vector2(-5, 5)))

func test_a_tap_beside_a_small_button_presses_it() -> void:
	_hide_layers_over_the_test()
	var button := _button(Vector2(100, 100), Vector2(10, 10))
	var presses: Array[bool] = []
	button.pressed.connect(func() -> void: presses.append(true))
	_tap(Vector2(92, 105))
	assert_eq(presses.size(), 1, "a tap beside it presses it")
	_tap(Vector2(80, 105))
	assert_eq(presses.size(), 1, "one further off does not")
	_click(Vector2(92, 105), true)
	_move(Vector2(96, 103))
	_click(Vector2(96, 103), false)
	assert_eq(presses.size(), 2, "a finger that wobbles beside it still presses it")
	_click(Vector2(92, 105), true)
	_move(Vector2(40, 105))
	_click(Vector2(40, 105), false)
	assert_eq(presses.size(), 2, "one that slides away lets go of it")
	InputPrompts.call("_set_using_touch", false)
	_tap(Vector2(92, 105), 0)
	assert_eq(presses.size(), 2, "the mouse clicks only on the button")
	_tap(Vector2(105, 105), 0)
	assert_eq(presses.size(), 3)

func test_watching_the_tree_gives_every_button_added_a_reach() -> void:
	TouchTarget.watch(get_tree())
	var button := Button.new()
	_layer.add_child(button)
	await get_tree().process_frame
	assert_not_null(TouchTarget.of(button), "a button added gets one")
	assert_eq(button.get_child_count(), 0, "which the game does not see among its children")
	TouchTarget.attach(button)
	assert_eq(button.get_child_count(true), 1, "and gets only one")
	TouchTarget.watch(get_tree(), false)
	var later := Button.new()
	_layer.add_child(later)
	await get_tree().process_frame
	assert_null(TouchTarget.of(later), "none once the watch stops")

func _button(at: Vector2, size: Vector2) -> TextureButton:
	var button := TextureButton.new()
	button.position = at
	_layer.add_child(button)
	button.size = size
	TouchTarget.attach(button)
	return button

func _hide_layers_over_the_test() -> void:
	for node: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if layer != _layer and layer.layer >= _layer.layer and layer.visible:
			layer.visible = false
			_hidden.append(layer)

# A tap of the first finger, as the mouse events the engine makes of it.
func _tap(at: Vector2, device := InputEvent.DEVICE_ID_EMULATION) -> void:
	_click(at, true, device)
	_click(at, false, device)

func _click(at: Vector2, pressed: bool, device := InputEvent.DEVICE_ID_EMULATION) -> void:
	var click := InputEventMouseButton.new()
	click.device = device
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.pressed = pressed
	click.position = get_tree().root.get_final_transform() * at
	click.global_position = click.position
	get_viewport().push_input(click)

func _move(to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = get_tree().root.get_final_transform() * to
	motion.global_position = motion.position
	get_viewport().push_input(motion)
