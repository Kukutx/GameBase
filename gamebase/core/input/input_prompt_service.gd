class_name InputPromptService
extends Node

## Which device the player is using, keyboard and mouse or a gamepad, and the
## text that names the key, button or stick of a control on it ("E", "A",
## "Left Stick") for the HUD and the interaction prompts. The bindings come from
## `GameSettings`; this service reads them and never changes them.
##
## The device switches on the last input: a gamepad button, or a stick or
## trigger pushed more than half way, picks the gamepad; a key or a mouse button
## picks the keyboard, the world paused or not (a menu's prompts follow too).
## `input_method_changed` fires on each switch, so prompts on screen can show
## the other device's names.

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
## The actions of the movement controls the core ships for games to list
## (`controls/move_*.tres`): up, left, down, right.
const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]

var using_gamepad := false

## The name of a gamepad button in prompts and the settings.
static func gamepad_button_name(button: JoyButton) -> String:
	if button == JOY_BUTTON_INVALID:
		return TranslationServer.translate("Unbound")
	if GAMEPAD_BUTTON_LABELS.has(button):
		return String(GAMEPAD_BUTTON_LABELS[button])
	return TranslationServer.translate("Button %d") % int(button)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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
			return gamepad_button_name(GameSettings.get_gamepad_binding(action))
		if control.gamepad_axis != JOY_AXIS_INVALID:
			return String(GAMEPAD_AXIS_LABELS.get(control.gamepad_axis, "Pad"))
	var key := GameSettings.get_key_binding(action)
	return OS.get_keycode_string(key) if key != KEY_NONE else tr("Unbound")

## The prompts of `actions` on the device in use, joined by "/".
func get_actions_prompt(actions: Array[StringName]) -> String:
	var prompts := PackedStringArray()
	for action: StringName in actions:
		prompts.append(get_action_prompt(action))
	return "/".join(prompts)

## How the player moves on the device in use: the stick on a gamepad, else the
## key bound to each of `actions`, then each one's fixed second key (the
## arrows) where it differs. The keys are those of `settings` (`GameSettings`
## when null).
func get_move_prompt(actions: Array[StringName] = MOVE_ACTIONS, settings: GameSettingsService = null) -> String:
	if using_gamepad:
		return tr("Left Stick / D-Pad")
	if settings == null:
		settings = GameSettings
	var bound := PackedStringArray()
	var second_keys := PackedStringArray()
	for action: StringName in actions:
		var key := settings.get_key_binding(action)
		bound.append(OS.get_keycode_string(key) if key != KEY_NONE else tr("Unbound"))
		var control := settings.get_control(action)
		if control != null and control.secondary_key != KEY_NONE and control.secondary_key != key:
			second_keys.append(OS.get_keycode_string(control.secondary_key))
	var prompt := "/".join(bound)
	return prompt if second_keys.is_empty() else "%s / %s" % [prompt, "/".join(second_keys)]

func _set_using_gamepad(value: bool) -> void:
	if using_gamepad == value:
		return
	using_gamepad = value
	input_method_changed.emit(using_gamepad)
