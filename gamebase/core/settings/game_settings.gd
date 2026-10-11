class_name GameSettingsService
extends Node

signal changed
signal controls_changed
signal locale_changed(locale: String)

## The settings are JSON: unlike `ConfigFile` or `str_to_var()`, whose text
## can name a resource to load or an object to build, JSON a file someone
## drops into the player's data folder can only hold values.
const DEFAULT_SETTINGS_PATH := "user://settings.json"
## The layout of the settings file; a file of another version is not read.
const SETTINGS_VERSION := 1
## Source text is English; the other locales are those the game registers
## translations for.
const SOURCE_LOCALE := "en"
## Each language's name in that language, for the language picker.
const LOCALE_NAMES := {
	"de": "Deutsch",
	"en": "English",
	"es": "Español",
	"fr": "Français",
	"it": "Italiano",
	"ja": "日本語",
	"ko": "한국어",
	"pl": "Polski",
	"pt_BR": "Português (Brasil)",
	"ru": "Русский",
	"tr": "Türkçe",
	"zh_CN": "简体中文",
	"zh_TW": "繁體中文",
}
## The controls the core's own systems read, as `ControlAction` paths. A game
## lists them in `GameDefinition.controls` only to place or replace them.
const CORE_CONTROLS: Array[String] = [
	"res://gamebase/core/input/controls/interact.tres",
	"res://gamebase/core/input/controls/quick_save.tres",
	"res://gamebase/core/input/controls/quick_load.tres",
]

var settings_path := DEFAULT_SETTINGS_PATH
var master_volume := 1.0
var music_volume := 0.8
var sounds_volume := 0.9
var fullscreen := false
var vsync := true
var autosave := true
var weather_effects := true
var reduced_motion := false
var locale := SOURCE_LOCALE
## Key of each rebindable action (String) the player chose or the default.
var key_bindings: Dictionary = {}

var _controls: Array[ControlAction] = []
## action (String) -> ControlAction
var _control_by_action: Dictionary = {}

## The running game's `GameDefinition.controls`; an entry that is not a
## `ControlAction` becomes null, which `find_control_problems()` reports.
static func game_controls() -> Array[ControlAction]:
	var result: Array[ControlAction] = []
	for entry: Resource in GameDefinition.current().controls:
		result.append(entry as ControlAction)
	return result

## The game's controls followed by the core's; a game control replaces the
## core's control of the same action.
static func resolve_controls(controls: Array[ControlAction]) -> Array[ControlAction]:
	var result: Array[ControlAction] = []
	var listed: Dictionary = {}
	for control: ControlAction in controls:
		if control != null:
			result.append(control)
			listed[control.action] = true
	for path: String in CORE_CONTROLS:
		var control := load(path) as ControlAction
		if not listed.has(control.action):
			result.append(control)
	return result

## What is wrong with a game's controls once the core's are added.
static func find_control_problems(controls: Array[ControlAction]) -> PackedStringArray:
	var problems := PackedStringArray()
	if controls.has(null):
		problems.append("GameDefinition.controls has an entry that is not a ControlAction")
	var actions: Dictionary = {}
	var key_owners: Dictionary = {}
	for control: ControlAction in resolve_controls(controls):
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
		if not control.rebindable:
			continue
		if control.display_name.is_empty():
			problems.append("rebindable control '%s' has no display name" % action)
		if control.key == KEY_NONE:
			problems.append("rebindable control '%s' has no default key" % action)
	return problems

func _init() -> void:
	for control: ControlAction in resolve_controls(game_controls()):
		_controls.append(control)
		_control_by_action[String(control.action)] = control

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

func set_autosave(value: bool) -> void:
	autosave = value
	_save_and_emit()

func set_weather_effects(value: bool) -> void:
	weather_effects = value
	_save_and_emit()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_save_and_emit()

func set_locale(value: String) -> void:
	locale = value if get_supported_locales().has(value) else SOURCE_LOCALE
	TranslationServer.set_locale(locale)
	save_settings()
	locale_changed.emit(locale)
	changed.emit()

## The source locale followed by every locale the game registers a translation for.
func get_supported_locales() -> PackedStringArray:
	var result := PackedStringArray([SOURCE_LOCALE])
	var loaded := TranslationServer.get_loaded_locales()
	loaded.sort()
	for loaded_locale: String in loaded:
		if not result.has(loaded_locale):
			result.append(loaded_locale)
	return result

func get_locale_display_name(value: String) -> String:
	return String(LOCALE_NAMES.get(value, TranslationServer.get_locale_name(value)))

## Every control of the running game, in settings order.
func get_controls() -> Array[ControlAction]:
	return _controls.duplicate()

## The declared control of `action`, or null.
func get_control(action: StringName) -> ControlAction:
	return _control_by_action.get(String(action)) as ControlAction

## The actions the player can rebind, in settings order.
func get_rebindable_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for control: ControlAction in _controls:
		if control.rebindable:
			result.append(control.action)
	return result

func get_control_label(action: StringName) -> String:
	var control := get_control(action)
	return tr(control.display_name) if control != null and not control.display_name.is_empty() else String(action)

func get_key_binding(action: StringName) -> Key:
	var control := get_control(action)
	if control == null:
		return KEY_NONE
	return int(key_bindings.get(String(action), int(control.key))) as Key

func get_key_binding_text(action: StringName) -> String:
	var key := get_key_binding(action)
	return OS.get_keycode_string(key) if key != KEY_NONE else tr("Unbound")

## Binds `key` to a rebindable action. The action that had the key takes the
## old one; a key another control holds fixed cannot be taken.
func set_key_binding(action: StringName, key: Key) -> bool:
	var control := get_control(action)
	if control == null or not control.rebindable or key == KEY_NONE or _is_fixed_key(key, action):
		return false
	var old_key := get_key_binding(action)
	for other: StringName in get_rebindable_actions():
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
	var controls := {}
	for action: StringName in get_rebindable_actions():
		controls[String(action)] = int(get_key_binding(action))
	var data := {
		"settings_version": SETTINGS_VERSION,
		"audio": {"master": master_volume, "music": music_volume, "sounds": sounds_volume},
		"display": {"fullscreen": fullscreen, "vsync": vsync},
		"gameplay": {"autosave": autosave},
		"accessibility": {"weather_effects": weather_effects, "reduced_motion": reduced_motion},
		"localization": {"locale": locale},
		"controls": controls,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings_path.get_base_dir()))
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		push_warning("GameSettings: could not write '%s' (%d)" % [settings_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

## Reads the settings from `settings_path`. A missing, unreadable or other
## version's file changes nothing; a value of the wrong type keeps the current
## one.
func load_settings() -> void:
	if key_bindings.is_empty():
		_reset_control_values()
	var json := JSON.new()
	if not FileAccess.file_exists(settings_path) or json.parse(FileAccess.get_file_as_string(settings_path)) != OK:
		return
	var data: Variant = json.data
	if not (data is Dictionary) or _read_number(data, "settings_version", "", 0.0) != SETTINGS_VERSION:
		return
	master_volume = clampf(_read_number(data, "audio", "master", master_volume), 0.0, 1.0)
	music_volume = clampf(_read_number(data, "audio", "music", music_volume), 0.0, 1.0)
	sounds_volume = clampf(_read_number(data, "audio", "sounds", sounds_volume), 0.0, 1.0)
	fullscreen = _read_bool(data, "display", "fullscreen", fullscreen)
	vsync = _read_bool(data, "display", "vsync", vsync)
	autosave = _read_bool(data, "gameplay", "autosave", autosave)
	weather_effects = _read_bool(data, "accessibility", "weather_effects", weather_effects)
	reduced_motion = _read_bool(data, "accessibility", "reduced_motion", reduced_motion)
	var loaded_locale: Variant = _read(data, "localization", "locale")
	locale = loaded_locale if loaded_locale is String and get_supported_locales().has(loaded_locale) else SOURCE_LOCALE
	for action: StringName in get_rebindable_actions():
		var fallback := int(get_control(action).key)
		var value := int(_read_number(data, "controls", String(action), fallback))
		key_bindings[String(action)] = value if value > 0 and not _is_fixed_key(value as Key, action) else fallback

# The value under `section` and `key` of the settings file's `data`, or null
# (`key` "" reads `section` itself).
static func _read(data: Dictionary, section: String, key: String) -> Variant:
	if key.is_empty():
		return data.get(section)
	var values: Variant = data.get(section)
	return (values as Dictionary).get(key) if values is Dictionary else null

static func _read_number(data: Dictionary, section: String, key: String, fallback: float) -> float:
	var value: Variant = _read(data, section, key)
	return float(value) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else fallback

static func _read_bool(data: Dictionary, section: String, key: String, fallback: bool) -> bool:
	var value: Variant = _read(data, section, key)
	return value if typeof(value) == TYPE_BOOL else fallback

## Whether a control other than `action`'s holds `key` in a way the player
## cannot swap: as its second key, or as the key of a control that is not
## rebindable.
func _is_fixed_key(key: Key, action: StringName) -> bool:
	for other: ControlAction in _controls:
		if other.action != action and (other.secondary_key == key or (not other.rebindable and other.key == key)):
			return true
	return false

func _reset_control_values() -> void:
	key_bindings.clear()
	for action: StringName in get_rebindable_actions():
		key_bindings[String(action)] = int(get_control(action).key)

func _apply_input_bindings() -> void:
	for control: ControlAction in _controls:
		if not InputMap.has_action(control.action):
			InputMap.add_action(control.action)
		InputMap.action_erase_events(control.action)
		for event: InputEvent in control.build_events(get_key_binding(control.action)):
			InputMap.action_add_event(control.action, event)

func _apply_bus(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0001)

func _save_and_emit() -> void:
	save_settings()
	changed.emit()
