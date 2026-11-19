extends GutTest

## The HUD's lines (`HudLine`): told again once at the end of a frame in which
## what they watch changed, an empty part left out and the line hidden while
## empty when it says so; the core's `ControlsLine` names each control the
## game has on the device in use.

signal fixture_changed(value: int)

## A line of the parts the test sets, which counts how often it is told.
class _FixtureLine:
	extends HudLine

	var parts := PackedStringArray()
	var told := 0
	var changed: Signal

	func _watch() -> void:
		watch(changed)

	func _get_parts() -> PackedStringArray:
		told += 1
		return parts

var _using_gamepad := false

func before_each() -> void:
	_using_gamepad = InputPrompts.using_gamepad

func after_each() -> void:
	InputPrompts.using_gamepad = _using_gamepad

func test_a_line_is_told_once_at_the_end_of_a_frame_in_which_what_it_watches_changed() -> void:
	var line := _FixtureLine.new()
	line.changed = fixture_changed
	line.separator = " | "
	line.parts = PackedStringArray(["a", "", "b"])
	add_child_autofree(line)
	await get_tree().process_frame
	assert_eq(line.text, "a | b", "an empty part is left out")
	var told := line.told
	line.parts = PackedStringArray(["c"])
	fixture_changed.emit(1)
	fixture_changed.emit(2)
	assert_eq(line.text, "a | b", "it waits for the end of the frame")
	await get_tree().process_frame
	assert_eq(line.text, "c")
	assert_eq(line.told, told + 1, "once for the frame")

func test_a_line_that_says_so_hides_while_it_has_nothing_to_tell() -> void:
	var line := _FixtureLine.new()
	line.changed = fixture_changed
	add_child_autofree(line)
	line.refresh()
	assert_true(line.visible, "a line shows though empty unless it says so")
	line.hides_when_empty = true
	line.parts = PackedStringArray([""])
	line.refresh()
	assert_false(line.visible)
	line.parts = PackedStringArray(["d"])
	line.refresh()
	assert_true(line.visible)

func test_the_controls_line_names_each_control_the_game_has_on_the_device_in_use() -> void:
	InputPrompts.using_gamepad = false
	var line := ControlsLine.new()
	var hints: Dictionary[StringName, String] = {&"interact": "use", &"fixture_no_control": "nothing", &"move": "move"}
	line.hints = hints
	add_child_autofree(line)
	await get_tree().process_frame
	assert_eq(line.text, "%s use · %s move" % [InputPrompts.get_prompt(&"interact"), InputPrompts.get_prompt(&"move")], "a control the game has not is left out")
	var keyboard := line.text
	InputPrompts.using_gamepad = true
	InputPrompts.input_method_changed.emit(true)
	await get_tree().process_frame
	assert_eq(line.text, "%s use · %s move" % [InputPrompts.get_prompt(&"interact"), InputPrompts.get_prompt(&"move")])
	assert_ne(line.text, keyboard, "a gamepad names its buttons")

func test_the_controls_line_names_a_module_s_control_while_the_module_names_it() -> void:
	InputPrompts.using_gamepad = false
	var line := ControlsLine.new()
	var hints: Dictionary[StringName, String] = {&"fixture_prompt": "pick", &"interact": "use"}
	line.hints = hints
	add_child_autofree(line)
	await get_tree().process_frame
	var interact := "%s use" % InputPrompts.get_prompt(&"interact")
	assert_eq(line.text, interact)
	var prompt := func() -> String: return "1-9"
	InputPrompts.register_prompt(&"fixture_prompt", prompt)
	await get_tree().process_frame
	assert_eq(line.text, "1-9 pick · %s" % interact, "a player added after the HUD brings its control")
	InputPrompts.unregister_prompt(&"fixture_prompt", prompt)
	await get_tree().process_frame
	assert_eq(line.text, interact, "and takes it away when it leaves")
