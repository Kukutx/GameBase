class_name ControlAction
extends Resource

## One input action and its default bindings.
##
## `GameSettings` builds the input map from these: the core's own controls
## (interact, quick save, quick load under `core/input/controls/`) and the
## controls the game lists in `GameDefinition.controls`. A rebindable control
## appears in the settings and keeps the player's key; its other bindings stay
## as declared.

@export var action: StringName = &""
## Name of the action in the controls settings, translated by the catalog of
## the layer that declares the control.
@export var display_name := ""
## Whether the player can change `key` in the settings.
@export var rebindable := true
## Default key, by physical position.
@export var key: Key = KEY_NONE
## A fixed second key, such as an arrow next to WASD.
@export var secondary_key: Key = KEY_NONE
@export var gamepad_button: JoyButton = JOY_BUTTON_INVALID
## A gamepad axis that triggers the action when pushed toward `gamepad_axis_value`.
@export var gamepad_axis: JoyAxis = JOY_AXIS_INVALID
@export_range(-1.0, 1.0, 2.0) var gamepad_axis_value := 1.0

## The input events of this control with `bound_key` as its key.
func build_events(bound_key: Key) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for event_key: Key in [bound_key, secondary_key if secondary_key != bound_key else KEY_NONE]:
		if event_key != KEY_NONE:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = event_key
			events.append(key_event)
	if gamepad_button != JOY_BUTTON_INVALID:
		var button := InputEventJoypadButton.new()
		button.button_index = gamepad_button
		events.append(button)
	if gamepad_axis != JOY_AXIS_INVALID:
		var motion := InputEventJoypadMotion.new()
		motion.axis = gamepad_axis
		motion.axis_value = gamepad_axis_value
		events.append(motion)
	return events
