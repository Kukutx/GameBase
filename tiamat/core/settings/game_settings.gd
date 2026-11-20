class_name GameSettingsService
extends Node

## The player's settings: the volumes, the display, autosave, how fast text
## types out, hints, accessibility, the language, the size and sides of the
## touch controls, vibration, the bindings of the controls (`bindings`) and
## the choices the game and its modules leave to the player (`options`).
## It applies them to the audio buses, the window, the frame rate, the
## translation server and the input map, and writes them to `settings_path` (JSON) once the frame of a
## change is done: a slider dragged across writes once a frame, not once a step.
## The file is replaced whole (`JsonFile`), so a crash never leaves half of it.
##
## The first launch, with no settings file yet, speaks the supported language
## nearest the system's (`GameLocales.nearest()`).
##
## Settings belong to the player, not to a save slot: starting or loading a game
## leaves them as they are. The controls are those of the game, its modules
## and the core (`GameControls`); binding one follows the rules of
## `ControlBindings`, which `bindings` reads. `changed` fires on any change,
## `controls_changed` when a binding changes, `option_changed` when an option
## does and `locale_changed` when the language does. As the game starts it makes the core's font (`GameFont`)
## the font every text shows in.

signal changed
signal controls_changed
signal option_changed(id: StringName, value: Variant)
signal locale_changed(locale: String)

## The settings are JSON: unlike `ConfigFile` or `str_to_var()`, whose text
## can name a resource to load or an object to build, JSON a file someone
## drops into the player's data folder can only hold values.
const DEFAULT_SETTINGS_PATH := "user://settings.json"
## The layout of the settings file; a file of another version is not read.
const SETTINGS_VERSION := 2
## How fast a dialogue types its lines out (`get_seconds_per_character()`).
enum TextSpeed { SLOW, NORMAL, FAST, INSTANT }
## Each text speed's name, as the settings file holds it and the menu shows it.
const TEXT_SPEED_NAMES: Array[String] = ["Slow", "Normal", "Fast", "Instant"]
# Characters a second of each text speed; 0 shows a line at once.
const _CHARACTERS_PER_SECOND: Array[float] = [25.0, 50.0, 100.0, 0.0]

## How large the touch controls show (`TouchControls`, `get_touch_scale()`).
enum TouchSize { SMALL, NORMAL, LARGE }
## Each touch size's name, as the settings file holds it and the menu shows it.
const TOUCH_SIZE_NAMES: Array[String] = ["Small", "Normal", "Large"]
# How much larger than its normal size each touch size draws the controls.
const _TOUCH_SCALES: Array[float] = [0.8, 1.0, 1.25]
## The faintest the touch controls draw (`touch_opacity`), still there to be
## found.
const TOUCH_OPACITY_MIN := 0.3

## The most frames a second a phone draws (`get_frame_rate_limit()`): its
## screen may refresh twice as often, which a game drawn at this size does not
## need and the battery pays for.
const PHONE_FRAME_RATE := 60
## The most frames a second the battery saver draws (`battery_saver`).
const BATTERY_SAVER_FRAME_RATE := 30

## The buses `GameAudio` plays on, each sending to Master. A game's bus
## layout may add effects to them; the core adds the ones it lacks.
const AUDIO_BUSES: Array[StringName] = [&"Music", &"Sounds"]

var settings_path := DEFAULT_SETTINGS_PATH
# The values `reset_all()` restores are those `_reset_values()` sets.
var master_volume: float
var music_volume: float
var sounds_volume: float
var fullscreen: bool
var vsync: bool
## Whether the game scales only by whole multiples, for sharp pixels.
var integer_scaling: bool
## Whether the game draws at most `BATTERY_SAVER_FRAME_RATE` frames a second,
## so a phone or laptop runs longer and cooler.
var battery_saver: bool
var autosave: bool
## Whether the pause menu opens when the game window loses focus.
var pause_on_focus_loss: bool
var text_speed: TextSpeed
## Whether the hints a game shows once show (`HintData`).
var hints: bool
var weather_effects: bool
var reduced_motion: bool
## Whether the player lets the game reach online services (an NPC chat's
## language model: `register_online_service()`); off until they turn it on.
var online_services: bool
var locale := GameLocales.SOURCE
## How large the touch controls show.
var touch_size: TouchSize
## Whether the touch controls swap sides: the stick at the lower right, the
## buttons at the lower left.
var touch_stick_right: bool
## How opaque the touch controls draw, from `TOUCH_OPACITY_MIN` to 1 (as
## drawn), so the player sees more of the game under them.
var touch_opacity: float
## Whether the gamepad or the phone shakes when the game says (`Haptics`).
var vibration: bool
## The controls of the running game and the player's bindings of them. Read
## them here; change them with `bind_control()`, `bind_gamepad_button()` and
## `reset_controls()`, which save and apply the change.
var bindings: ControlBindings
## The options of the running game (`GameOption`) and the player's value of
## each: read one with `get_option()`, change it with `set_option()`.
var options: GameOptions

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
	options = GameOptions.of_running_game()

func _ready() -> void:
	ensure_audio_buses()
	locale = GameLocales.nearest(GameLocales.system, GameLocales.supported())
	load_settings()
	WindowMemory.restore()
	apply()

# A change the frame did not write yet is written as the game quits, and the
# window is remembered where the player left it.
func _exit_tree() -> void:
	if _save_pending:
		save_settings()
	WindowMemory.remember()

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
	_apply_window_mode()
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

func set_battery_saver(value: bool) -> void:
	battery_saver = value
	_apply_frame_rate()
	_save_and_emit()

## The window mode `fullscreen` asks of a window now in `current`, or -1 to
## leave it: a full screen, or a window that leaves full screen (a maximized
## window stays maximized). A phone keeps the mode its export gives it, its
## system bars hidden, which any window mode would end on Android.
static func window_mode_for(full: bool, current: DisplayServer.WindowMode, phone: bool) -> int:
	var is_full := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if phone or full == is_full:
		return -1
	return DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED

## The most frames a second the game draws (`Engine.max_fps`; 0 for no
## limit, where vsync holds it to the screen): the game's own limit
## (`application/run/max_fps`), lowered to `BATTERY_SAVER_FRAME_RATE` with the
## battery saver on and to `PHONE_FRAME_RATE` on a phone.
func get_frame_rate_limit() -> int:
	var limit := int(ProjectSettings.get_setting("application/run/max_fps", 0))
	var cap := 0
	if battery_saver:
		cap = BATTERY_SAVER_FRAME_RATE
	elif InputPromptService.starts_on_touch():
		cap = PHONE_FRAME_RATE
	if cap > 0 and (limit <= 0 or cap < limit):
		limit = cap
	return limit

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

func set_hints(value: bool) -> void:
	hints = value
	_save_and_emit()

func set_text_speed(value: TextSpeed) -> void:
	text_speed = clampi(value, 0, TextSpeed.size() - 1) as TextSpeed
	_save_and_emit()

## How long a dialogue shows each character before the next at the player's
## text speed; 0 shows a whole line at once.
func get_seconds_per_character() -> float:
	var per_second := _CHARACTERS_PER_SECOND[text_speed]
	return 1.0 / per_second if per_second > 0.0 else 0.0

func set_touch_size(value: TouchSize) -> void:
	touch_size = clampi(value, 0, TouchSize.size() - 1) as TouchSize
	_save_and_emit()

## How much larger than their normal size the touch controls show.
func get_touch_scale() -> float:
	return _TOUCH_SCALES[touch_size]

func set_touch_stick_right(value: bool) -> void:
	touch_stick_right = value
	_save_and_emit()

func set_touch_opacity(value: float) -> void:
	touch_opacity = clampf(value, TOUCH_OPACITY_MIN, 1.0)
	_save_and_emit()

func set_vibration(value: bool) -> void:
	vibration = value
	_save_and_emit()

func set_weather_effects(value: bool) -> void:
	weather_effects = value
	_save_and_emit()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_save_and_emit()

func set_locale(value: String) -> void:
	locale = value if GameLocales.is_supported(value) else GameLocales.SOURCE
	TranslationServer.set_locale(locale)
	_request_save()
	locale_changed.emit(locale)
	changed.emit()

## The player's value of the game's option `id` (`GameOption`): a bool, a
## choice's name or a float.
func get_option(id: StringName) -> Variant:
	return options.get_value(id)

## Sets the game's option `id` to `value`, held to what the option takes.
func set_option(id: StringName, value: Variant) -> void:
	if options.set_value(id, value):
		_request_save()
		option_changed.emit(id, options.get_value(id))
		changed.emit()

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

## Restores every setting but the language to its default, the controls and
## the options included.
func reset_all() -> void:
	_reset_values()
	bindings.reset()
	options.reset()
	for option: GameOption in options.get_declared():
		option_changed.emit(option.id, options.get_value(option.id))
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
	_apply_frame_rate()
	_apply_window_mode()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := window_mode_for(fullscreen, DisplayServer.window_get_mode(), OS.has_feature("mobile"))
	if mode >= 0:
		DisplayServer.window_set_mode(mode as DisplayServer.WindowMode)

## The settings as the file holds them.
func to_data() -> Dictionary:
	var controls := bindings.to_data()
	return {
		"settings_version": SETTINGS_VERSION,
		"audio": {"master": master_volume, "music": music_volume, "sounds": sounds_volume},
		"display": {"fullscreen": fullscreen, "vsync": vsync, "integer_scaling": integer_scaling, "battery_saver": battery_saver},
		"gameplay": {"autosave": autosave, "pause_on_focus_loss": pause_on_focus_loss, "text_speed": TEXT_SPEED_NAMES[text_speed].to_lower(), "hints": hints, "vibration": vibration},
		"accessibility": {"weather_effects": weather_effects, "reduced_motion": reduced_motion},
		"privacy": {"online_services": online_services},
		"touch": {"size": TOUCH_SIZE_NAMES[touch_size].to_lower(), "stick_right": touch_stick_right, "opacity": touch_opacity},
		"localization": {"locale": locale},
		"controls": controls["controls"],
		"gamepad": controls["gamepad"],
		"options": options.to_data(),
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
## reads as the source language, and the controls and the options read as
## `ControlBindings.read_data()` and `GameOptions.read_data()` tell.
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
	battery_saver = _read_bool(data, "display", "battery_saver", battery_saver)
	autosave = _read_bool(data, "gameplay", "autosave", autosave)
	pause_on_focus_loss = _read_bool(data, "gameplay", "pause_on_focus_loss", pause_on_focus_loss)
	var speed: Variant = _read(data, "gameplay", "text_speed")
	for index: int in TEXT_SPEED_NAMES.size():
		if speed is String and speed == TEXT_SPEED_NAMES[index].to_lower():
			text_speed = index as TextSpeed
	hints = _read_bool(data, "gameplay", "hints", hints)
	vibration = _read_bool(data, "gameplay", "vibration", vibration)
	weather_effects = _read_bool(data, "accessibility", "weather_effects", weather_effects)
	reduced_motion = _read_bool(data, "accessibility", "reduced_motion", reduced_motion)
	online_services = _read_bool(data, "privacy", "online_services", online_services)
	var size: Variant = _read(data, "touch", "size")
	for index: int in TOUCH_SIZE_NAMES.size():
		if size is String and size == TOUCH_SIZE_NAMES[index].to_lower():
			touch_size = index as TouchSize
	touch_stick_right = _read_bool(data, "touch", "stick_right", touch_stick_right)
	touch_opacity = clampf(_read_number(data, "touch", "opacity", touch_opacity), TOUCH_OPACITY_MIN, 1.0)
	var loaded_locale: Variant = _read(data, "localization", "locale")
	locale = loaded_locale if GameLocales.is_supported(loaded_locale) else GameLocales.SOURCE
	bindings.read_data(data.get("controls"), data.get("gamepad"))
	options.read_data(data.get("options"))

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
	battery_saver = false
	autosave = true
	pause_on_focus_loss = true
	text_speed = TextSpeed.NORMAL
	hints = true
	weather_effects = true
	reduced_motion = false
	online_services = false
	touch_size = TouchSize.NORMAL
	touch_stick_right = false
	touch_opacity = 1.0
	vibration = true

# Set only on a change: each change lays out every embedded window again.
func _apply_scaling() -> void:
	if not is_inside_tree():
		return
	var stretch := Window.CONTENT_SCALE_STRETCH_INTEGER if integer_scaling else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if get_tree().root.content_scale_stretch != stretch:
		get_tree().root.content_scale_stretch = stretch

# A headless run (the tests) keeps the engine's rate, so a test's frames do
# not wait on a setting.
func _apply_frame_rate() -> void:
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = get_frame_rate_limit()

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
