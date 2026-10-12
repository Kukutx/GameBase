class_name ControlAction
extends Resource

## One input action and its default bindings.
##
## `GameSettings` builds the input map from these (`ControlBindings`): the
## controls the game lists in `GameDefinition.controls`, those its modules
## declare (`GameModule.get_controls()`) and the core's own (moving,
## interacting, quick save and load under `core/input/controls/`). A
## rebindable control appears in the settings and keeps the player's key or
## mouse button and gamepad button; its second key and stick direction stay as
## declared. Its events answer every device (`ALL_DEVICES`), so any gamepad
## plays, not only the first.

## The device of an event that matches input from any device.
const ALL_DEVICES := -1

@export var action: StringName = &""
## Name of the action in the controls settings, translated by the catalog of
## the layer that declares the control.
@export var display_name := ""
## Where the action is read, which the settings show as a heading: empty for
## the world, or a name such as "Battle" for the controls of one minigame,
## translated like `display_name`. Controls of one group never share a key, a
## mouse button or a gamepad button; controls of two groups may, as a battle's
## command may take a key the world walks with.
@export var group := ""
## Whether the player can change the control's key or mouse button and its
## gamepad button in the settings.
@export var rebindable := true
## Default key, by physical position.
@export var key: Key = KEY_NONE
## Default mouse button, for a control without a default `key`.
@export var mouse_button: MouseButton = MOUSE_BUTTON_NONE
## A fixed second key, such as an arrow next to WASD.
@export var secondary_key: Key = KEY_NONE
@export var gamepad_button: JoyButton = JOY_BUTTON_INVALID
## A gamepad axis that triggers the action when pushed toward `gamepad_axis_value`.
@export var gamepad_axis: JoyAxis = JOY_AXIS_INVALID
@export_range(-1.0, 1.0, 2.0) var gamepad_axis_value := 1.0

## The declared key or mouse button, as `ControlBindings` holds a binding:
## `{"key": key}`, `{"mouse": button}` or {} for neither.
func get_default_binding() -> Dictionary:
	if key != KEY_NONE:
		return {"key": int(key)}
	if mouse_button != MOUSE_BUTTON_NONE:
		return {"mouse": int(mouse_button)}
	return {}

## The input events of this control with `binding` (a key or mouse button, as
## `get_default_binding()` gives one) and `bound_button` as its gamepad button.
func build_events(binding: Dictionary, bound_button: JoyButton) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	var bound_key := int(binding.get("key", KEY_NONE)) as Key
	for event_key: Key in [bound_key, secondary_key if secondary_key != bound_key else KEY_NONE]:
		if event_key != KEY_NONE:
			var key_event := InputEventKey.new()
			key_event.device = ALL_DEVICES
			key_event.physical_keycode = event_key
			events.append(key_event)
	if binding.has("mouse"):
		var click := InputEventMouseButton.new()
		click.device = ALL_DEVICES
		click.button_index = int(binding["mouse"]) as MouseButton
		events.append(click)
	if bound_button != JOY_BUTTON_INVALID:
		var button := InputEventJoypadButton.new()
		button.device = ALL_DEVICES
		button.button_index = bound_button
		events.append(button)
	if gamepad_axis != JOY_AXIS_INVALID:
		var motion := InputEventJoypadMotion.new()
		motion.device = ALL_DEVICES
		motion.axis = gamepad_axis
		motion.axis_value = gamepad_axis_value
		events.append(motion)
	return events
