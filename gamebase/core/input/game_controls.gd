class_name GameControls
extends RefCounted

## The controls of the running game: the game's `ControlAction`s
## (`GameDefinition.controls`) followed by the core's own (`CORE`), and what is
## wrong with them. `GameSettings` binds the player's keys and buttons to them.

## The controls the core's own systems read, as `ControlAction` paths: the
## moves a `TopDownPlayer` walks with, interacting and the quick save and load.
## A game lists them in `GameDefinition.controls` only to place or replace them.
const CORE: Array[String] = [
	"res://gamebase/core/input/controls/move_up.tres",
	"res://gamebase/core/input/controls/move_down.tres",
	"res://gamebase/core/input/controls/move_left.tres",
	"res://gamebase/core/input/controls/move_right.tres",
	"res://gamebase/core/input/controls/interact.tres",
	"res://gamebase/core/input/controls/quick_save.tres",
	"res://gamebase/core/input/controls/quick_load.tres",
]

## The running game's `GameDefinition.controls`; an entry that is not a
## `ControlAction` becomes null, which `find_problems()` reports.
static func of_game() -> Array[ControlAction]:
	var result: Array[ControlAction] = []
	for entry: Resource in GameDefinition.current().controls:
		result.append(entry as ControlAction)
	return result

## The game's controls followed by the core's; a game control replaces the
## core's control of the same action.
static func resolve(controls: Array[ControlAction]) -> Array[ControlAction]:
	var result: Array[ControlAction] = []
	var listed: Dictionary = {}
	for control: ControlAction in controls:
		if control != null:
			result.append(control)
			listed[control.action] = true
	for path: String in CORE:
		var control := load(path) as ControlAction
		if not listed.has(control.action):
			result.append(control)
	return result

## What is wrong with a game's controls once the core's are added.
static func find_problems(controls: Array[ControlAction]) -> PackedStringArray:
	var problems := PackedStringArray()
	if controls.has(null):
		problems.append("GameDefinition.controls has an entry that is not a ControlAction")
	var actions: Dictionary = {}
	var key_owners: Dictionary = {}
	var button_owners: Dictionary = {}
	for control: ControlAction in resolve(controls):
		var action := String(control.action)
		if action.is_empty():
			problems.append("a control has no action")
			continue
		if actions.has(action):
			problems.append("control '%s' is listed twice" % action)
			continue
		actions[action] = true
		var bound := control.key != KEY_NONE or control.secondary_key != KEY_NONE
		if not bound and control.gamepad_button == JOY_BUTTON_INVALID and control.gamepad_axis == JOY_AXIS_INVALID:
			problems.append("control '%s' has no key, button or axis" % action)
		for default_key: Key in [control.key, control.secondary_key]:
			if default_key == KEY_NONE or key_owners.get(default_key, "") == action:
				continue
			if key_owners.has(default_key):
				problems.append("controls '%s' and '%s' share the default key %s" % [key_owners[default_key], action, OS.get_keycode_string(default_key)])
			else:
				key_owners[default_key] = action
		if control.gamepad_button != JOY_BUTTON_INVALID:
			if button_owners.has(control.gamepad_button):
				problems.append("controls '%s' and '%s' share the default gamepad button %s" % [button_owners[control.gamepad_button], action, InputPromptService.gamepad_button_name(control.gamepad_button)])
			else:
				button_owners[control.gamepad_button] = action
		if not control.rebindable:
			continue
		if control.display_name.is_empty():
			problems.append("rebindable control '%s' has no display name" % action)
		if control.key == KEY_NONE:
			problems.append("rebindable control '%s' has no default key" % action)
	return problems
