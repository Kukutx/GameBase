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

func get_action_prompt(action: StringName) -> String:
	if using_gamepad:
		var button := GameSettings.get_gamepad_button(action)
		if button >= 0:
			return String(GAMEPAD_BUTTON_LABELS.get(button, "Pad"))
	var key := GameSettings.get_key_binding(action)
	return OS.get_keycode_string(key) if key != KEY_NONE else tr("Unbound")

func get_hotbar_prompt() -> String:
	return tr("LT/RT") if using_gamepad else tr("1–9")

func get_move_prompt() -> String:
	return tr("Left Stick / D-Pad") if using_gamepad else tr("WASD / Arrows")

func get_controls_summary() -> String:
	if using_gamepad:
		return tr("%s move · %s interact/reel · %s tool/item · %s gift · %s pack · %s menu · %s hotbar · %s/%s save/load") % [
			get_move_prompt(),
			get_action_prompt(&"interact"),
			get_action_prompt(&"use_tool"),
			get_action_prompt(&"give_gift"),
			get_action_prompt(&"remove_building"),
			get_action_prompt(&"open_menu"),
			get_hotbar_prompt(),
			get_action_prompt(&"quick_save"),
			get_action_prompt(&"quick_load"),
		]
	return tr("%s move · %s interact/reel · %s tool/item · %s gift · %s pack · %s menu · %s hotbar · %s/%s save/load") % [
		get_move_prompt(),
		get_action_prompt(&"interact"),
		get_action_prompt(&"use_tool"),
		get_action_prompt(&"give_gift"),
		get_action_prompt(&"remove_building"),
		get_action_prompt(&"open_menu"),
		get_hotbar_prompt(),
		get_action_prompt(&"quick_save"),
		get_action_prompt(&"quick_load"),
	]

func _set_using_gamepad(value: bool) -> void:
	if using_gamepad == value:
		return
	using_gamepad = value
	input_method_changed.emit(using_gamepad)
