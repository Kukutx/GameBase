class_name ControlBindings
extends RefCounted

## The player's bindings of a game's controls (`ControlAction`) and the input
## map built of them. A rebindable control keeps the key or mouse button and
## the gamepad button the player chose, or its defaults; its second key and
## stick direction stay as declared. `GameSettings` holds the running game's
## (`GameSettings.bindings`), changes them and saves them.
##
## A binding of the keyboard and mouse side is a dictionary, as the settings
## file holds it: `{"key": key}` (by physical position) or `{"mouse": button}`.
## Controls of one `ControlAction.group` share no binding: binding one that
## another control of the group has swaps the two, and one that a control of
## the group holds fixed (a second key, or the binding of a control the player
## cannot rebind) is refused. Controls of two groups, the world's and a
## battle's, may share one.

## Each mouse button's name in prompts and the settings.
const MOUSE_BUTTON_NAMES := {
	MOUSE_BUTTON_LEFT: "Mouse Left",
	MOUSE_BUTTON_RIGHT: "Mouse Right",
	MOUSE_BUTTON_MIDDLE: "Mouse Middle",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
	MOUSE_BUTTON_WHEEL_LEFT: "Wheel Left",
	MOUSE_BUTTON_WHEEL_RIGHT: "Wheel Right",
	MOUSE_BUTTON_XBUTTON1: "Mouse Back",
	MOUSE_BUTTON_XBUTTON2: "Mouse Forward",
}

var _controls: Array[ControlAction] = []
var _by_action: Dictionary[StringName, ControlAction] = {}
# action -> the binding the player chose, of a rebindable control.
var _bindings: Dictionary[StringName, Dictionary] = {}
# action -> the gamepad button the player chose (JoyButton).
var _buttons: Dictionary[StringName, int] = {}

func _init(controls: Array[ControlAction]) -> void:
	for control: ControlAction in controls:
		_controls.append(control)
		_by_action[control.action] = control

## The binding of `event`, a key or mouse button press; {} for anything else.
static func binding_of(event: InputEvent) -> Dictionary:
	var key := event as InputEventKey
	if key != null:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return {"key": int(code)} if code != KEY_NONE else {}
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index != MOUSE_BUTTON_NONE:
		return {"mouse": int(mouse.button_index)}
	return {}

## Whether `binding` names a key or a mouse button.
static func is_binding(binding: Dictionary) -> bool:
	if binding.size() != 1:
		return false
	var kind: Variant = binding.keys()[0]
	var code: Variant = binding.values()[0]
	return (kind == "key" or kind == "mouse") and typeof(code) == TYPE_INT and int(code) > 0

## The name of `binding` in prompts and the settings, in the player's
## language: "E", "Mouse Right".
static func binding_text(binding: Dictionary) -> String:
	if binding.has("mouse"):
		var button := int(binding["mouse"])
		if MOUSE_BUTTON_NAMES.has(button):
			return TranslationServer.translate(MOUSE_BUTTON_NAMES[button])
		return TranslationServer.translate("Mouse %d") % button
	return binding_name(binding) if binding.has("key") else TranslationServer.translate("Unbound")

## The name of `binding` in English, for logs and support bundles.
static func binding_name(binding: Dictionary) -> String:
	if binding.has("key"):
		return OS.get_keycode_string(int(binding["key"]) as Key)
	if binding.has("mouse"):
		return String(MOUSE_BUTTON_NAMES.get(int(binding["mouse"]), "Mouse %d" % int(binding["mouse"])))
	return "Unbound"

## Every control, in settings order.
func get_controls() -> Array[ControlAction]:
	return _controls.duplicate()

## The control of `action`, or null.
func get_control(action: StringName) -> ControlAction:
	return _by_action.get(action) as ControlAction

## The actions the player can rebind, in settings order.
func get_rebindable_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for control: ControlAction in _controls:
		if control.rebindable:
			result.append(control.action)
	return result

## The control's name in the settings, translated.
func get_label(action: StringName) -> String:
	var control := get_control(action)
	if control == null or control.display_name.is_empty():
		return String(action)
	return TranslationServer.translate(control.display_name)

## The key or mouse button of `action`: the player's for a rebindable control,
## else the declared one; {} for none.
func get_binding(action: StringName) -> Dictionary:
	var control := get_control(action)
	if control == null:
		return {}
	return (_bindings[action] if _bindings.has(action) else control.get_default_binding()).duplicate()

func get_binding_text(action: StringName) -> String:
	return binding_text(get_binding(action))

## Whether the player can change the gamepad button of `action`: a rebindable
## control that declares one.
func has_gamepad_binding(action: StringName) -> bool:
	var control := get_control(action)
	return control != null and control.rebindable and control.gamepad_button != JOY_BUTTON_INVALID

## The gamepad button of `action`: the player's for a rebindable control, else
## the declared one (`JOY_BUTTON_INVALID` for none).
func get_gamepad_button(action: StringName) -> JoyButton:
	var control := get_control(action)
	if control == null:
		return JOY_BUTTON_INVALID
	return int(_buttons.get(action, int(control.gamepad_button))) as JoyButton

## Binds `binding` to the rebindable `action`; the control of its group that
## had it takes the old one. False, and nothing changes, when a control of the
## group holds it, or would hold the old one, fixed.
func bind(action: StringName, binding: Dictionary) -> bool:
	var control := get_control(action)
	if control == null or not control.rebindable or not is_binding(binding) or _holds_fixed(binding, control):
		return false
	var old := get_binding(action)
	var holder := _holder_of(binding, control)
	if holder != null:
		if _holds_fixed(old, holder):
			return false
		_bindings[holder.action] = old
	_bindings[action] = binding.duplicate()
	return true

## Binds gamepad `button` to `action`, a control with a gamepad button; the
## control of its group that had it takes the old one. False, and nothing
## changes, when a control of the group the player cannot rebind holds it.
func bind_gamepad_button(action: StringName, button: JoyButton) -> bool:
	var control := get_control(action)
	if not has_gamepad_binding(action) or button < 0 or button >= JOY_BUTTON_MAX or _holds_fixed_button(button, control):
		return false
	var old := get_gamepad_button(action)
	for other: ControlAction in _controls:
		if other != control and other.group == control.group and has_gamepad_binding(other.action) and get_gamepad_button(other.action) == button:
			_buttons[other.action] = int(old)
			break
	_buttons[action] = int(button)
	return true

## Gives every control its declared bindings back.
func reset() -> void:
	_bindings.clear()
	_buttons.clear()

## The bindings as the settings file holds them: the rebindable controls' keys
## or mouse buttons (`controls`) and gamepad buttons (`gamepad`).
func to_data() -> Dictionary:
	var controls := {}
	var gamepad := {}
	for action: StringName in get_rebindable_actions():
		controls[String(action)] = get_binding(action)
		if has_gamepad_binding(action):
			gamepad[String(action)] = int(get_gamepad_button(action))
	return {"controls": controls, "gamepad": gamepad}

## Reads the bindings `to_data()` gave back. A control without a usable
## binding there keeps its default, and so does one whose binding a control of
## its group holds fixed; bindings that leave two controls of a group sharing
## one read as the defaults, every one of them.
func read_data(controls: Variant, gamepad: Variant) -> void:
	reset()
	for action: StringName in get_rebindable_actions():
		var control := get_control(action)
		var binding := _read_binding(controls.get(String(action)) if controls is Dictionary else null)
		if is_binding(binding) and not _holds_fixed(binding, control):
			_bindings[action] = binding
		if not has_gamepad_binding(action):
			continue
		var button: Variant = SaveValues.whole_number(gamepad.get(String(action)) if gamepad is Dictionary else null)
		if button != null and int(button) >= 0 and int(button) < JOY_BUTTON_MAX and not _holds_fixed_button(int(button) as JoyButton, control):
			_buttons[action] = int(button)
	if _has_clash():
		reset()

## Builds the input map's events of every control from its bindings.
func apply_to_input_map() -> void:
	for control: ControlAction in _controls:
		if not InputMap.has_action(control.action):
			InputMap.add_action(control.action)
		InputMap.action_erase_events(control.action)
		for event: InputEvent in control.build_events(get_binding(control.action), get_gamepad_button(control.action)):
			InputMap.action_add_event(control.action, event)

# A binding as the settings file holds it, its number whole; {} when it is
# none.
static func _read_binding(value: Variant) -> Dictionary:
	if not value is Dictionary or (value as Dictionary).size() != 1:
		return {}
	var kind := String((value as Dictionary).keys()[0])
	var code: Variant = SaveValues.whole_number((value as Dictionary).values()[0])
	return {kind: int(code)} if (kind == "key" or kind == "mouse") and code != null else {}

# The rebindable control of `control`'s group other than it bound to
# `binding`, or null.
func _holder_of(binding: Dictionary, control: ControlAction) -> ControlAction:
	for other: ControlAction in _controls:
		if other != control and other.rebindable and other.group == control.group and get_binding(other.action) == binding:
			return other
	return null

# Whether a control of `control`'s group other than it holds `binding` in a
# way the player cannot swap: as its second key, or as the binding of a
# control that is not rebindable.
func _holds_fixed(binding: Dictionary, control: ControlAction) -> bool:
	for other: ControlAction in _controls:
		if other == control or other.group != control.group:
			continue
		if binding.has("key") and other.secondary_key != KEY_NONE and int(other.secondary_key) == int(binding["key"]):
			return true
		if not other.rebindable and other.get_default_binding() == binding:
			return true
	return false

# Whether a control of `control`'s group other than it that the player cannot
# rebind holds gamepad `button`.
func _holds_fixed_button(button: JoyButton, control: ControlAction) -> bool:
	for other: ControlAction in _controls:
		if other != control and other.group == control.group and not other.rebindable and other.gamepad_button == button:
			return true
	return false

# Whether two rebindable controls of a group share a binding or a gamepad
# button.
func _has_clash() -> bool:
	var taken := {}
	for control: ControlAction in _controls:
		if not control.rebindable:
			continue
		var binding := get_binding(control.action)
		var marks := PackedStringArray()
		if not binding.is_empty():
			marks.append("%s|%s" % [control.group, JSON.stringify(binding)])
		if has_gamepad_binding(control.action):
			marks.append("%s|pad %d" % [control.group, int(get_gamepad_button(control.action))])
		for mark: String in marks:
			if taken.has(mark):
				return true
			taken[mark] = true
	return false
