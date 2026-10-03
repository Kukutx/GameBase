class_name GameSettingsService
extends Node

signal changed
signal controls_changed
signal locale_changed(locale: String)

const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALE_IDS := ["en", "zh_CN"]
const LOCALE_DISPLAY_NAMES := {
	"en": "English",
	"zh_CN": "简体中文",
}
const CONTROL_ACTIONS = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"interact", &"use_tool", &"give_gift", &"remove_building",
	&"open_menu", &"quick_save", &"quick_load",
]
const CONTROL_LABELS := {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"interact": "Interact / Reel",
	"use_tool": "Use Tool / Item",
	"give_gift": "Give Gift",
	"remove_building": "Pack Building",
	"open_menu": "Open Menu",
	"quick_save": "Quick Save",
	"quick_load": "Quick Load",
}
const DEFAULT_CONTROL_KEYS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"interact": KEY_E,
	"use_tool": KEY_F,
	"give_gift": KEY_G,
	"remove_building": KEY_R,
	"open_menu": KEY_I,
	"quick_save": KEY_K,
	"quick_load": KEY_L,
}
const SECONDARY_CONTROL_KEYS := {
	"move_up": KEY_UP,
	"move_down": KEY_DOWN,
	"move_left": KEY_LEFT,
	"move_right": KEY_RIGHT,
}
const DEFAULT_GAMEPAD_BUTTONS := {
	"interact": JOY_BUTTON_A,
	"use_tool": JOY_BUTTON_X,
	"give_gift": JOY_BUTTON_Y,
	"remove_building": JOY_BUTTON_RIGHT_SHOULDER,
	"open_menu": JOY_BUTTON_START,
	"quick_save": JOY_BUTTON_LEFT_STICK,
	"quick_load": JOY_BUTTON_RIGHT_STICK,
}

var settings_path := DEFAULT_SETTINGS_PATH
var master_volume := 1.0
var music_volume := 0.8
var sounds_volume := 0.9
var fullscreen := false
var vsync := true
var locale := "en"
var key_bindings: Dictionary = {}

func _ready() -> void:
	_reset_control_values()
	load_settings()
	apply()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"Master", master_volume)
	_save_and_emit()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"Music", music_volume)
	_save_and_emit()

func set_sounds_volume(value: float) -> void:
	sounds_volume = clampf(value, 0.0, 1.0)
	_apply_bus(&"Sounds", sounds_volume)
	_save_and_emit()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_and_emit()

func set_vsync(value: bool) -> void:
	vsync = value
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_save_and_emit()

func set_locale(value: String) -> void:
	var resolved := value if SUPPORTED_LOCALE_IDS.has(value) else "en"
	locale = resolved
	TranslationServer.set_locale(locale)
	save_settings()
	locale_changed.emit(locale)
	changed.emit()

func get_supported_locales() -> PackedStringArray:
	return PackedStringArray(SUPPORTED_LOCALE_IDS)

func get_locale_display_name(value: String) -> String:
	return String(LOCALE_DISPLAY_NAMES.get(value, value))

func get_control_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for action: StringName in CONTROL_ACTIONS:
		result.append(action)
	return result

func get_control_label(action: StringName) -> String:
	return tr(String(CONTROL_LABELS.get(String(action), String(action).capitalize())))

func get_key_binding(action: StringName) -> Key:
	var raw := int(key_bindings.get(String(action), int(DEFAULT_CONTROL_KEYS.get(String(action), KEY_NONE))))
	return raw as Key

func get_key_binding_text(action: StringName) -> String:
	var key := get_key_binding(action)
	return OS.get_keycode_string(key) if key != KEY_NONE else tr("Unbound")

func set_key_binding(action: StringName, key: Key) -> bool:
	if not CONTROL_ACTIONS.has(action) or key == KEY_NONE:
		return false
	var old_key := get_key_binding(action)
	for other: StringName in CONTROL_ACTIONS:
		if other == action:
			continue
		if get_key_binding(other) == key:
			key_bindings[String(other)] = int(old_key)
			break
	key_bindings[String(action)] = int(key)
	_apply_input_bindings()
	save_settings()
	controls_changed.emit()
	changed.emit()
	return true

func reset_controls() -> void:
	_reset_control_values()
	_apply_input_bindings()
	save_settings()
	controls_changed.emit()
	changed.emit()

func apply() -> void:
	TranslationServer.set_locale(locale)
	_apply_bus(&"Master", master_volume)
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"Sounds", sounds_volume)
	_apply_input_bindings()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sounds", sounds_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("localization", "locale", locale)
	for action: StringName in CONTROL_ACTIONS:
		config.set_value("controls", String(action), int(get_key_binding(action)))
	config.save(settings_path)

func load_settings() -> void:
	if key_bindings.is_empty():
		_reset_control_values()
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music", 0.8)), 0.0, 1.0)
	sounds_volume = clampf(float(config.get_value("audio", "sounds", 0.9)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	vsync = bool(config.get_value("display", "vsync", true))
	var loaded_locale := String(config.get_value("localization", "locale", "en"))
	locale = loaded_locale if SUPPORTED_LOCALE_IDS.has(loaded_locale) else "en"
	for action: StringName in CONTROL_ACTIONS:
		var fallback := int(DEFAULT_CONTROL_KEYS[String(action)])
		var value := int(config.get_value("controls", String(action), fallback))
		key_bindings[String(action)] = value if value > 0 else fallback

func _reset_control_values() -> void:
	key_bindings.clear()
	for action: StringName in CONTROL_ACTIONS:
		key_bindings[String(action)] = int(DEFAULT_CONTROL_KEYS[String(action)])

func _apply_input_bindings() -> void:
	for action: StringName in CONTROL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		_add_key_event(action, get_key_binding(action))
		var secondary := int(SECONDARY_CONTROL_KEYS.get(String(action), KEY_NONE)) as Key
		if secondary != KEY_NONE and secondary != get_key_binding(action):
			_add_key_event(action, secondary)
		_add_gamepad_movement_events(action)
		_add_gamepad_action_event(action)

func _add_key_event(action: StringName, key: Key) -> void:
	if key == KEY_NONE:
		return
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _add_gamepad_action_event(action: StringName) -> void:
	var raw_button := int(DEFAULT_GAMEPAD_BUTTONS.get(String(action), -1))
	if raw_button < 0:
		return
	var event := InputEventJoypadButton.new()
	event.button_index = raw_button as JoyButton
	InputMap.action_add_event(action, event)

func _add_gamepad_movement_events(action: StringName) -> void:
	var button_index := -1
	var axis := -1
	var axis_value := 0.0
	match action:
		&"move_left":
			button_index = JOY_BUTTON_DPAD_LEFT
			axis = JOY_AXIS_LEFT_X
			axis_value = -1.0
		&"move_right":
			button_index = JOY_BUTTON_DPAD_RIGHT
			axis = JOY_AXIS_LEFT_X
			axis_value = 1.0
		&"move_up":
			button_index = JOY_BUTTON_DPAD_UP
			axis = JOY_AXIS_LEFT_Y
			axis_value = -1.0
		&"move_down":
			button_index = JOY_BUTTON_DPAD_DOWN
			axis = JOY_AXIS_LEFT_Y
			axis_value = 1.0
		_:
			return
	var button := InputEventJoypadButton.new()
	button.button_index = button_index
	InputMap.action_add_event(action, button)
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = axis_value
	InputMap.action_add_event(action, motion)

func _apply_bus(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0001)

func _save_and_emit() -> void:
	save_settings()
	changed.emit()
