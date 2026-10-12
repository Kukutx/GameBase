class_name GameSettingsService
extends Node

## The player's settings: the volumes, the display, autosave, how fast text
## types out, accessibility, the language and the bindings of the controls
## (`bindings`).
## It applies them to the audio buses, the window, the translation server and
## the input map, and writes them to `settings_path` (JSON) once the frame of a
## change is done: a slider dragged across writes once a frame, not once a step.
## The file is replaced whole (`JsonFile`), so a crash never leaves half of it.
##
## The first launch, with no settings file yet, speaks the supported language
## nearest the system's (`system_locale`, `nearest_locale()`).
##
## Settings belong to the player, not to a save slot: starting or loading a game
## leaves them as they are. The controls are those of the game, its modules
## and the core (`GameControls`); binding one follows the rules of
## `ControlBindings`, which `bindings` reads. `changed` fires on any change,
## `controls_changed` when a binding changes and `locale_changed` when the
## language does. As the game starts it makes the core's font (`GameFont`)
## the font every text shows in.

signal changed
signal controls_changed
signal locale_changed(locale: String)

## The settings are JSON: unlike `ConfigFile` or `str_to_var()`, whose text
## can name a resource to load or an object to build, JSON a file someone
## drops into the player's data folder can only hold values.
const DEFAULT_SETTINGS_PATH := "user://settings.json"
## The layout of the settings file; a file of another version is not read.
const SETTINGS_VERSION := 2
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

## How fast a dialogue types its lines out (`get_seconds_per_character()`).
enum TextSpeed { SLOW, NORMAL, FAST, INSTANT }
## Each text speed's name, as the settings file holds it and the menu shows it.
const TEXT_SPEED_NAMES: Array[String] = ["Slow", "Normal", "Fast", "Instant"]
# Characters a second of each text speed; 0 shows a line at once.
const _CHARACTERS_PER_SECOND: Array[float] = [25.0, 50.0, 100.0, 0.0]

## The buses `GameAudio` plays on, each sending to Master. A game's bus
## layout may add effects to them; the core adds the ones it lacks.
const AUDIO_BUSES: Array[StringName] = [&"Music", &"Sounds"]

## The system's language as the game starts (`OS.get_locale()`); a test run
## sets the source language here, so no test depends on the machine's.
static var system_locale := OS.get_locale()

var settings_path := DEFAULT_SETTINGS_PATH
# The values `reset_all()` restores are those `_reset_values()` sets.
var master_volume: float
var music_volume: float
var sounds_volume: float
var fullscreen: bool
var vsync: bool
## Whether the game scales only by whole multiples, for sharp pixels.
var integer_scaling: bool
var autosave: bool
## Whether the pause menu opens when the game window loses focus.
var pause_on_focus_loss: bool
var text_speed: TextSpeed
var weather_effects: bool
var reduced_motion: bool
## Whether the player lets the game reach online services (an NPC chat's
## language model: `register_online_service()`); off until they turn it on.
var online_services: bool
var locale := SOURCE_LOCALE
## The controls of the running game and the player's bindings of them. Read
## them here; change them with `bind_control()`, `bind_gamepad_button()` and
## `reset_controls()`, which save and apply the change.
var bindings: ControlBindings

# Whether a change waits to be written at the end of its frame.
var _save_pending := false
# id -> Callable() -> bool: whether the game uses the online service now.
var _online_services: Dictionary[StringName, Callable] = {}

## Adds each of `AUDIO_BUSES` the project's bus layout lacks, sending to Master.
static func ensure_audio_buses() -> void:
	for bus_name: StringName in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")

func _init() -> void:
	GameFont.use(load(GameFont.PATH) as Font)
	_reset_values()
	bindings = ControlBindings.new(GameControls.of_running_game())

func _ready() -> void:
	ensure_audio_buses()
	locale = nearest_locale(system_locale, get_supported_locales())
	load_settings()
	apply()

# A change the frame did not write yet is written as the game quits.
func _exit_tree() -> void:
	if _save_pending:
		save_settings()

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

func set_integer_scaling(value: bool) -> void:
	integer_scaling = value
	_apply_scaling()
	_save_and_emit()

func set_autosave(value: bool) -> void:
	autosave = value
	_save_and_emit()

func set_pause_on_focus_loss(value: bool) -> void:
	pause_on_focus_loss = value
	_save_and_emit()

func set_online_services(value: bool) -> void:
	online_services = value
	_save_and_emit()

## Registers an online service a module can reach (`id`), which the game uses
## while `is_used.call()` holds (it names an endpoint). The service goes online
## only while `online_services` is on, and the settings menu offers that
## choice while the game uses any.
func register_online_service(id: StringName, is_used: Callable) -> void:
	_online_services[id] = is_used

## Whether the game uses any online service (`register_online_service()`).
func uses_online_services() -> bool:
	return _online_services.values().any(func(is_used: Callable) -> bool: return is_used.is_valid() and bool(is_used.call()))

func set_text_speed(value: TextSpeed) -> void:
	text_speed = clampi(value, 0, TextSpeed.size() - 1) as TextSpeed
	_save_and_emit()

## How long a dialogue shows each character before the next at the player's
## text speed; 0 shows a whole line at once.
func get_seconds_per_character() -> float:
	var per_second := _CHARACTERS_PER_SECOND[text_speed]
	return 1.0 / per_second if per_second > 0.0 else 0.0

func set_weather_effects(value: bool) -> void:
	weather_effects = value
	_save_and_emit()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_save_and_emit()

func set_locale(value: String) -> void:
	locale = value if get_supported_locales().has(value) else SOURCE_LOCALE
	TranslationServer.set_locale(locale)
	_request_save()
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

## The locale of `supported` nearest `system` (an `OS.get_locale()`): the same
## one, else one of the same language (a Traditional Chinese system reads
## Simplified Chinese before English), else the source language.
static func nearest_locale(system: String, supported: PackedStringArray) -> String:
	var nearest := SOURCE_LOCALE
	var nearest_score := 0
	for candidate: String in supported:
		var score := TranslationServer.compare_locales(system, candidate)
		if score > nearest_score:
			nearest = candidate
			nearest_score = score
	return nearest

func get_locale_display_name(value: String) -> String:
	return String(LOCALE_NAMES.get(value, TranslationServer.get_locale_name(value)))

## Binds `binding`, a key or mouse button (`ControlBindings`), to the
## rebindable `action`; false when the rules of `ControlBindings` refuse it.
func bind_control(action: StringName, binding: Dictionary) -> bool:
	return _changed_controls(bindings.bind(action, binding))

## Binds gamepad `button` to `action`; false when the rules of
## `ControlBindings` refuse it.
func bind_gamepad_button(action: StringName, button: JoyButton) -> bool:
	return _changed_controls(bindings.bind_gamepad_button(action, button))

## Gives every control its declared bindings back.
func reset_controls() -> void:
	bindings.reset()
	_changed_controls(true)

## Restores every setting but the language to its default, controls included.
func reset_all() -> void:
	_reset_values()
	bindings.reset()
	apply()
	_request_save()
	controls_changed.emit()
	changed.emit()

func apply() -> void:
	TranslationServer.set_locale(locale)
	_apply_bus(&"Master", master_volume)
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"Sounds", sounds_volume)
	bindings.apply_to_input_map()
	_apply_scaling()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

## The settings as the file holds them.
func to_data() -> Dictionary:
	var controls := bindings.to_data()
	return {
		"settings_version": SETTINGS_VERSION,
		"audio": {"master": master_volume, "music": music_volume, "sounds": sounds_volume},
		"display": {"fullscreen": fullscreen, "vsync": vsync, "integer_scaling": integer_scaling},
		"gameplay": {"autosave": autosave, "pause_on_focus_loss": pause_on_focus_loss, "text_speed": TEXT_SPEED_NAMES[text_speed].to_lower()},
		"accessibility": {"weather_effects": weather_effects, "reduced_motion": reduced_motion},
		"privacy": {"online_services": online_services},
		"localization": {"locale": locale},
		"controls": controls["controls"],
		"gamepad": controls["gamepad"],
	}

## Writes the settings to `settings_path` now. A change writes them by itself
## at the end of its frame.
func save_settings() -> void:
	_save_pending = false
	var problem := JsonFile.write(settings_path, to_data())
	if not problem.is_empty():
		push_warning("GameSettings: " + problem)

## Reads the settings from `settings_path`. A missing, unreadable or other
## version's file changes nothing. In a file that is read, a value of the wrong
## type keeps the current one, except that a locale the game does not support
## reads as the source language, and the controls read as
## `ControlBindings.read_data()` tells.
func load_settings() -> void:
	var data: Variant = JsonFile.read(settings_path)
	if not (data is Dictionary) or _read_number(data, "settings_version", "", 0.0) != SETTINGS_VERSION:
		return
	master_volume = clampf(_read_number(data, "audio", "master", master_volume), 0.0, 1.0)
	music_volume = clampf(_read_number(data, "audio", "music", music_volume), 0.0, 1.0)
	sounds_volume = clampf(_read_number(data, "audio", "sounds", sounds_volume), 0.0, 1.0)
	fullscreen = _read_bool(data, "display", "fullscreen", fullscreen)
	vsync = _read_bool(data, "display", "vsync", vsync)
	integer_scaling = _read_bool(data, "display", "integer_scaling", integer_scaling)
	autosave = _read_bool(data, "gameplay", "autosave", autosave)
	pause_on_focus_loss = _read_bool(data, "gameplay", "pause_on_focus_loss", pause_on_focus_loss)
	var speed: Variant = _read(data, "gameplay", "text_speed")
	for index: int in TEXT_SPEED_NAMES.size():
		if speed is String and speed == TEXT_SPEED_NAMES[index].to_lower():
			text_speed = index as TextSpeed
	weather_effects = _read_bool(data, "accessibility", "weather_effects", weather_effects)
	reduced_motion = _read_bool(data, "accessibility", "reduced_motion", reduced_motion)
	online_services = _read_bool(data, "privacy", "online_services", online_services)
	var loaded_locale: Variant = _read(data, "localization", "locale")
	locale = loaded_locale if loaded_locale is String and get_supported_locales().has(loaded_locale) else SOURCE_LOCALE
	bindings.read_data(data.get("controls"), data.get("gamepad"))

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

func _reset_values() -> void:
	master_volume = 1.0
	music_volume = 0.8
	sounds_volume = 0.9
	fullscreen = false
	vsync = true
	integer_scaling = false
	autosave = true
	pause_on_focus_loss = true
	text_speed = TextSpeed.NORMAL
	weather_effects = true
	reduced_motion = false
	online_services = false

# Set only on a change: each change lays out every embedded window again.
func _apply_scaling() -> void:
	if not is_inside_tree():
		return
	var stretch := Window.CONTENT_SCALE_STRETCH_INTEGER if integer_scaling else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if get_tree().root.content_scale_stretch != stretch:
		get_tree().root.content_scale_stretch = stretch

func _apply_bus(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0001)

# Applies, saves and tells a change of the bindings when `bound`; gives
# `bound` back.
func _changed_controls(bound: bool) -> bool:
	if bound:
		bindings.apply_to_input_map()
		_request_save()
		controls_changed.emit()
		changed.emit()
	return bound

func _save_and_emit() -> void:
	_request_save()
	changed.emit()

# Writes the settings once the frame is done, however many changes it made.
func _request_save() -> void:
	if not _save_pending:
		_save_pending = true
		_save_when_idle.call_deferred()

func _save_when_idle() -> void:
	if _save_pending:
		save_settings()
