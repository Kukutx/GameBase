class_name InputPromptService
extends Node

## Which device the player is using, keyboard and mouse or a gamepad, and the
## text that names the key, button or stick of a control on it ("E", "A",
## "Left Stick") for the HUD and the interaction prompts. The bindings come from
## `GameSettings.bindings`; this service reads them and never changes them.
##
## The device switches on the last input: a gamepad button, or a stick or
## trigger pushed more than half way, picks the gamepad; a key or a mouse button
## picks the keyboard, the world paused or not (a menu's prompts follow too).
## A gamepad's buttons are named as its maker prints them (`gamepad_style`,
## told from its name): A, B, X and Y on an Xbox pad, ×, ○, □ and △ on a
## PlayStation one, B, A, Y and X on a Nintendo one. `input_method_changed`
## fires on each switch of device or of kind of gamepad, so prompts on screen
## can show the other names. When the gamepad in use disconnects, the prompts
## go back to the keyboard and `gamepad_disconnected` fires (the pause menu
## opens on it).
##
## A finger on a touchscreen picks touch (`using_touch`), until a key, a mouse
## button or a gamepad is used again; the mouse clicks the engine makes of a
## finger keep touch. On touch a control is named as its button on the screen
## names it (its name in the settings) and moving as the stick, since the
## `TouchControls` show; `input_method_changed` fires on that switch too. A
## phone or a tablet, or a browser on one, starts on touch (`starts_on_touch()`),
## so the first hint names the stick, not keys it has none of.

signal input_method_changed(using_gamepad: bool)
signal gamepad_disconnected
## A module named or took back the prompt of a control (`register_prompt()`),
## so a line that names the controls names them anew.
signal prompts_changed

## How a gamepad's maker names its buttons.
enum GamepadStyle { XBOX, PLAYSTATION, NINTENDO }

## The words in a gamepad's name (`Input.get_joy_name()`) that tell its
## style; any other gamepad is named as an Xbox pad is.
const STYLE_WORDS := {
	GamepadStyle.PLAYSTATION: ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"],
	GamepadStyle.NINTENDO: ["nintendo", "switch", "joy-con", "joycon"],
}
## Each button's name on an Xbox pad, in prompts and the settings.
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
## The names another style gives in place of the Xbox pad's.
const STYLE_BUTTON_LABELS := {
	GamepadStyle.PLAYSTATION: {
		JOY_BUTTON_A: "×",
		JOY_BUTTON_B: "○",
		JOY_BUTTON_X: "□",
		JOY_BUTTON_Y: "△",
		JOY_BUTTON_BACK: "Share",
		JOY_BUTTON_START: "Options",
		JOY_BUTTON_LEFT_SHOULDER: "L1",
		JOY_BUTTON_RIGHT_SHOULDER: "R1",
	},
	GamepadStyle.NINTENDO: {
		JOY_BUTTON_A: "B",
		JOY_BUTTON_B: "A",
		JOY_BUTTON_X: "Y",
		JOY_BUTTON_Y: "X",
		JOY_BUTTON_BACK: "-",
		JOY_BUTTON_START: "+",
		JOY_BUTTON_LEFT_STICK: "LS",
		JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "L",
		JOY_BUTTON_RIGHT_SHOULDER: "R",
	},
}
const GAMEPAD_AXIS_LABELS := {
	JOY_AXIS_LEFT_X: "Left Stick",
	JOY_AXIS_LEFT_Y: "Left Stick",
	JOY_AXIS_RIGHT_X: "Right Stick",
	JOY_AXIS_RIGHT_Y: "Right Stick",
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}
const STYLE_AXIS_LABELS := {
	GamepadStyle.PLAYSTATION: {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2"},
	GamepadStyle.NINTENDO: {JOY_AXIS_TRIGGER_LEFT: "ZL", JOY_AXIS_TRIGGER_RIGHT: "ZR"},
}
## The actions of the movement controls the core ships for games to list
## (`controls/move_*.tres`): up, left, down, right.
const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]
## The arrow keys in the order of `MOVE_ACTIONS`, which a move prompt names
## as one ("Arrows").
const ARROW_KEYS: Array[Key] = [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]

var using_gamepad := false
## Whether the player plays by touch, which `TouchControls` show for.
var using_touch := false
## How the gamepad last used names its buttons.
var gamepad_style := GamepadStyle.XBOX

# The device of the gamepad last used, or -1.
var _gamepad_device := -1
# name -> how a module prompts it (`register_prompt()`).
var _prompts: Dictionary[StringName, Callable] = {}

## The style of a gamepad named `joy_name` (`Input.get_joy_name()`).
static func style_of(joy_name: String) -> GamepadStyle:
	var words := joy_name.to_lower()
	for style: int in STYLE_WORDS:
		for word: String in STYLE_WORDS[style]:
			if words.contains(word):
				return style as GamepadStyle
	return GamepadStyle.XBOX

## The name of a gamepad button on a pad of `style`, in prompts and the
## settings.
static func gamepad_button_name(button: JoyButton, style := GamepadStyle.XBOX) -> String:
	if button == JOY_BUTTON_INVALID:
		return TranslationServer.translate("Unbound")
	var labels: Dictionary = STYLE_BUTTON_LABELS.get(style, {})
	if labels.has(button):
		return String(labels[button])
	if GAMEPAD_BUTTON_LABELS.has(button):
		return String(GAMEPAD_BUTTON_LABELS[button])
	return TranslationServer.translate("Button %d") % int(button)

## The name of a gamepad axis on a pad of `style`.
static func gamepad_axis_name(axis: JoyAxis, style := GamepadStyle.XBOX) -> String:
	var labels: Dictionary = STYLE_AXIS_LABELS.get(style, {})
	return String(labels.get(axis, GAMEPAD_AXIS_LABELS.get(axis, "Pad")))

## Whether the device the game runs on is played by touch before anything is
## pressed: a phone or a tablet, or a browser on one.
static func starts_on_touch() -> bool:
	for feature: String in ["mobile", "web_android", "web_ios"]:
		if OS.has_feature(feature):
			return true
	return false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	using_touch = starts_on_touch()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

## Whether a mouse event is a finger's: one the engine makes of the first
## finger, or one `TouchControls` makes of a second.
static func is_from_finger(event: InputEvent) -> bool:
	return event.device == InputEvent.DEVICE_ID_EMULATION or event.device == TouchControlsService.FINGER_MOUSE_DEVICE

## The device of the gamepad the player is using, or -1 when they use
## something else.
func get_gamepad_in_use() -> int:
	return _gamepad_device if using_gamepad else -1

## The name of gamepad `button` on the gamepad in use.
func get_button_name(button: JoyButton) -> String:
	return gamepad_button_name(button, gamepad_style)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_set_using_touch(true)
		return
	if event is InputEventMouse and is_from_finger(event):
		return
	if event is InputEventJoypadButton:
		if event.pressed:
			_use_gamepad(event.device)
		return
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) >= 0.55:
			_use_gamepad(event.device)
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			_set_using_gamepad(false)
			_set_using_touch(false)
		return
	if event is InputEventMouseButton and event.pressed:
		_set_using_gamepad(false)
		_set_using_touch(false)

## The key, mouse button, gamepad button or axis that performs `action` on
## the device in use. An action of the engine's that the game declares no
## control for (`ui_cancel`, `ui_accept`) is named from the input map: its
## first gamepad button while a pad plays, else its first key, and on touch ×
## for `ui_cancel` (the close button over a menu) or empty, the rest being
## tapped.
func get_action_prompt(action: StringName) -> String:
	var bindings := GameSettings.bindings
	var control := bindings.get_control(action)
	if control == null and InputMap.has_action(action):
		return _input_map_prompt(action)
	if using_touch and control != null:
		return bindings.get_label(action)
	if using_gamepad and control != null:
		if control.gamepad_button != JOY_BUTTON_INVALID:
			return get_button_name(bindings.get_gamepad_button(action))
		if control.gamepad_axis != JOY_AXIS_INVALID:
			return gamepad_axis_name(control.gamepad_axis, gamepad_style)
	return bindings.get_binding_text(action)

# The prompt of `action`, no control of the game's, from its events in the
# input map: its gamepad button while a pad plays, else (as a control with no
# button) its key; empty where it has neither.
func _input_map_prompt(action: StringName) -> String:
	if using_touch:
		return "×" if action == &"ui_cancel" else ""
	var key := ""
	for event: InputEvent in InputMap.action_get_events(action):
		if using_gamepad and event is InputEventJoypadButton:
			return get_button_name((event as InputEventJoypadButton).button_index)
		if key.is_empty() and event is InputEventKey:
			var pressed := event as InputEventKey
			key = ControlBindings.key_text(pressed.physical_keycode if pressed.physical_keycode != KEY_NONE else pressed.keycode)
	return key

## The prompt of `control` on the device in use, as the HUD names a control
## (`ControlsLine`): what a module registered under that name
## (`register_prompt()`: the hotbar's number keys), the movement for `move`,
## the actions of `quick_save/quick_load` joined by "/", else the action's
## own. Empty for a name that is no control of the game.
func get_prompt(control: StringName) -> String:
	if _prompts.has(control):
		return String(_prompts[control].call())
	if control == &"move":
		return get_move_prompt()
	var actions: Array[StringName] = []
	for action: String in String(control).split("/", false):
		if GameSettings.bindings.get_control(StringName(action)) != null:
			actions.append(StringName(action))
	return get_actions_prompt(actions)

## Names the prompt of a control that is no single action, such as the slots
## of a hotbar: `prompt` returns its text on the device in use, empty while
## the player cannot use it. A later registration of `name` replaces it.
func register_prompt(name: StringName, prompt: Callable) -> void:
	_prompts[name] = prompt
	prompts_changed.emit()

## Takes back `prompt` of `name` unless another has replaced it since.
func unregister_prompt(name: StringName, prompt: Callable) -> void:
	if _prompts.get(name) == prompt:
		_prompts.erase(name)
		prompts_changed.emit()

## The prompts of `actions` on the device in use, joined by "/".
func get_actions_prompt(actions: Array[StringName]) -> String:
	var prompts := PackedStringArray()
	for action: StringName in actions:
		prompts.append(get_action_prompt(action))
	return "/".join(prompts)

## How the player moves on the device in use: the stick on a gamepad, else the
## key or mouse button bound to each of `actions`, then each one's fixed second
## key (the arrows) where it differs: "WASD / Arrows", a run of letters written
## as one word and the four arrows, in their order, as one name. The bindings
## are `bindings` (`GameSettings.bindings` when null).
func get_move_prompt(actions: Array[StringName] = MOVE_ACTIONS, bindings: ControlBindings = null) -> String:
	if using_gamepad:
		return tr("Left Stick / D-Pad")
	if using_touch:
		return tr("Stick")
	if bindings == null:
		bindings = GameSettings.bindings
	var bound := PackedStringArray()
	var second_keys: Array[Key] = []
	for action: StringName in actions:
		var binding := bindings.get_binding(action)
		bound.append(ControlBindings.binding_text(binding))
		var control := bindings.get_control(action)
		if control != null and control.secondary_key != KEY_NONE and int(control.secondary_key) != int(binding.get("key", KEY_NONE)):
			second_keys.append(control.secondary_key)
	var prompt := _join_keys(bound)
	if second_keys.is_empty():
		return prompt
	if second_keys == ARROW_KEYS:
		return "%s / %s" % [prompt, tr("Arrows")]
	var seconds := PackedStringArray()
	for key: Key in second_keys:
		seconds.append(ControlBindings.key_text(key))
	return "%s / %s" % [prompt, _join_keys(seconds)]

# Key names joined for a prompt: single letters as one word ("WASD"), any
# longer name between slashes ("Up/A/S/D").
static func _join_keys(names: PackedStringArray) -> String:
	for key_name: String in names:
		if key_name.length() != 1:
			return "/".join(names)
	return "".join(names)

func _use_gamepad(device: int) -> void:
	if device != _gamepad_device:
		_gamepad_device = device
		_set_gamepad_style(style_of(Input.get_joy_name(device)))
	_set_using_gamepad(true)

func _set_gamepad_style(style: GamepadStyle) -> void:
	if gamepad_style == style:
		return
	gamepad_style = style
	if using_gamepad:
		input_method_changed.emit(using_gamepad)

func _set_using_gamepad(value: bool) -> void:
	if value:
		_set_using_touch(false)
	if using_gamepad == value:
		return
	using_gamepad = value
	input_method_changed.emit(using_gamepad)

func _set_using_touch(value: bool) -> void:
	if using_touch == value:
		return
	using_touch = value
	if value and using_gamepad:
		using_gamepad = false
	input_method_changed.emit(using_gamepad)

# The gamepad in use leaving takes the prompts back to the keyboard and has
# the game wait for the player.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or device != _gamepad_device:
		return
	_gamepad_device = -1
	var was_used := using_gamepad
	_set_using_gamepad(false)
	if was_used:
		gamepad_disconnected.emit()
