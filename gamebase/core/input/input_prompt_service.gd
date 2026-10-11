class_name InputPromptService
extends Node

signal input_method_changed(using_gamepad: bool)

const GAMEPAD_BUTTON_LABELS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-Pad ↑",
	JOY_BUTTON_DPAD_DOWN: "D-Pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-Pad ←",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad →",
}
const GAMEPAD_AXIS_LABELS := {
	JOY_AXIS_LEFT_X: "Left Stick",
	JOY_AXIS_LEFT_Y: "Left Stick",
	JOY_AXIS_RIGHT_X: "Right Stick",
	JOY_AXIS_RIGHT_Y: "Right Stick",
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}

var using_gamepad := false

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed:
			_set_using_gamepad(true)
		return
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) >= 0.55:
			_set_using_gamepad(true)
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			_set_using_gamepad(false)
		return
	if event is InputEventMouseButton and event.pressed:
		_set_using_gamepad(false)

## The key, button or axis that performs `action` on the device in use.
func get_action_prompt(action: StringName) -> String:
	var control := GameSettings.get_control(action)
	if using_gamepad and control != null:
		if control.gamepad_button != JOY_BUTTON_INVALID:
			return String(GAMEPAD_BUTTON_LABELS.get(control.gamepad_button, "Pad"))
		if control.gamepad_axis != JOY_AXIS_INVALID:
			return String(GAMEPAD_AXIS_LABELS.get(control.gamepad_axis, "Pad"))
	var key := GameSettings.get_key_binding(action)
	return OS.get_keycode_string(key) if key != KEY_NONE else tr("Unbound")

func _set_using_gamepad(value: bool) -> void:
	if using_gamepad == value:
		return
	using_gamepad = value
	input_method_changed.emit(using_gamepad)
