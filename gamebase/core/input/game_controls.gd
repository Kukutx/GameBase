class_name GameControls
extends RefCounted

## The controls of the running game: the game's `ControlAction`s
## (`GameDefinition.controls`), then those its modules declare
## (`GameModule.get_controls()`), then the core's own (`CORE`), and what is
## wrong with them. `GameSettings` binds the player's keys and buttons to them
## (`ControlBindings`).

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

## The controls the game's modules declare, in the order they install.
static func of_modules() -> Array[ControlAction]:
	var result: Array[ControlAction] = []
	for script: Script in GameModulesService.find_module_scripts():
		result.append_array((script.new() as GameModule).get_controls())
	return result

## The running game's controls, in settings order (`resolve()`).
static func of_running_game() -> Array[ControlAction]:
	return resolve(of_game(), of_modules())

## The game's controls, then its modules', then the core's; the first control
## of an action replaces the later ones, so a game replaces a module's control
## or the core's by listing its action.
static func resolve(game_controls: Array[ControlAction], module_controls: Array[ControlAction]) -> Array[ControlAction]:
	var result: Array[ControlAction] = []
	var listed: Dictionary[StringName, bool] = {}
	var core_controls: Array[ControlAction] = []
	for path: String in CORE:
		core_controls.append(load(path) as ControlAction)
	for control: ControlAction in game_controls + module_controls + core_controls:
		if control != null and not listed.has(control.action):
			result.append(control)
			listed[control.action] = true
	return result

## What is wrong with a game's controls once its modules' and the core's are
## added.
static func find_problems(game_controls: Array[ControlAction], module_controls: Array[ControlAction]) -> PackedStringArray:
	var problems := PackedStringArray()
	if game_controls.has(null):
		problems.append("GameDefinition.controls has an entry that is not a ControlAction")
	if module_controls.has(null):
		problems.append("a module declares a control that is not a ControlAction")
	for action: StringName in _find_repeated(game_controls):
		problems.append("control '%s' is listed twice" % action)
	for action: StringName in _find_repeated(module_controls):
		problems.append("two modules declare control '%s'" % action)
	# group|binding -> the action that holds it by default.
	var owners: Dictionary[String, String] = {}
	for control: ControlAction in resolve(game_controls, module_controls):
		var action := String(control.action)
		if action.is_empty():
			problems.append("a control has no action")
			continue
		problems.append_array(_find_control_problems(control))
		var held: Dictionary[String, String] = {}
		for default_key: Key in [control.key, control.secondary_key]:
			if default_key != KEY_NONE:
				held["key %d" % default_key] = "key " + OS.get_keycode_string(default_key)
		if control.mouse_button != MOUSE_BUTTON_NONE:
			held["mouse %d" % control.mouse_button] = "mouse button %s" % ControlBindings.MOUSE_BUTTON_NAMES.get(control.mouse_button, control.mouse_button)
		if control.gamepad_button != JOY_BUTTON_INVALID:
			held["pad %d" % control.gamepad_button] = "gamepad button " + InputPromptService.gamepad_button_name(control.gamepad_button)
		for input: String in held:
			var mark := "%s|%s" % [control.group, input]
			if owners.has(mark):
				problems.append("controls '%s' and '%s' share the default %s" % [owners[mark], action, held[input]])
			else:
				owners[mark] = action
	return problems

# The actions that more than one of `controls` has.
static func _find_repeated(controls: Array[ControlAction]) -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	var repeated: Array[StringName] = []
	for control: ControlAction in controls:
		if control == null or control.action == &"":
			continue
		if seen.has(control.action) and not repeated.has(control.action):
			repeated.append(control.action)
		seen[control.action] = true
	return repeated

static func _find_control_problems(control: ControlAction) -> PackedStringArray:
	var problems := PackedStringArray()
	var action := String(control.action)
	if control.key != KEY_NONE and control.mouse_button != MOUSE_BUTTON_NONE:
		problems.append("control '%s' has both a default key and a default mouse button" % action)
	if control.get_default_binding().is_empty() and control.secondary_key == KEY_NONE and control.gamepad_button == JOY_BUTTON_INVALID and control.gamepad_axis == JOY_AXIS_INVALID:
		problems.append("control '%s' has no key, mouse button, gamepad button or axis" % action)
	if not control.rebindable:
		return problems
	if control.display_name.is_empty():
		problems.append("rebindable control '%s' has no display name" % action)
	if control.get_default_binding().is_empty():
		problems.append("rebindable control '%s' has no default key or mouse button" % action)
	return problems
