class_name GameDefinition
extends Resource

## The facts the foundation needs about the game that is running on it.
##
## `gamebase/core` never names a location, item or other content id of a
## particular game. A game provides one `GameDefinition` resource and points the
## `gamebase/game_definition` project setting at it; `GameSession` loads it.

## Project setting naming the running game's definition resource.
const SETTING := "gamebase/game_definition"

static var _current: GameDefinition

## The running game's definition, loaded once from the `gamebase/game_definition`
## project setting. Usable from any autoload, whatever its order.
static func current() -> GameDefinition:
	if _current == null:
		var path := String(ProjectSettings.get_setting(SETTING, ""))
		var loaded: Resource = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
		if loaded is GameDefinition:
			_current = loaded
		else:
			push_error("GameDefinition: project setting '%s' must point to a GameDefinition resource (got '%s')" % [SETTING, path])
			_current = GameDefinition.new()
	return _current

## The game's content: every entry of these packs, indexed by `ContentDB`
## under the kind its class is registered as.
@export var content: Array[ContentPack] = []
## Location a new game starts in, and the fallback when a save's location is gone.
@export var start_location_id: StringName = &""
## Location the player wakes in after passing out (`GameSession.pass_out()`).
@export var home_location_id: StringName = &""
## Spawn point used when the player is brought home.
@export var home_spawn_id: StringName = &""
## How the game counts its time: seasons, week, clock speed, night and the
## player's day (`GameCalendar`). None: the default calendar of four 28-day
## seasons.
@export var calendar: GameCalendar
## Clock at the start of a new game.
@export_range(1, 100000) var start_day := 1
@export_range(0, 1439) var start_minute_of_day := 8 * 60
## How many save slots the title screen offers, each with the player's save
## and an autosave (`SaveManager`).
@export_range(1, 9) var save_slots := 3
## Seed of a new game's world randomness (`GameRandom`): the weather, catches,
## mine floors and more. 0 gives each new game a fresh seed.
@export var world_seed := 0
## The chances of each weather in each season (`GameWeatherSystem`); a day
## they give no other weather has `clear_weather_id`.
@export var weather_odds: Array[WeatherOdds] = []
## The weather (`WeatherData`) of a day the odds give no other; empty, with no
## odds, for a game without weather.
@export var clear_weather_id: StringName = &""
## Audio cue played for an event, as `<Autoload>.<signal>`
## (`LifesimEvents.crop_harvested`) → cue id; from where it happened when the
## event carries a `position` (`GameAudio`).
@export var event_cues: Dictionary[StringName, StringName] = {}
## The sounds of the menus (`GameAudio.MenuSound`): the focus moving with the
## keys or a gamepad, a button pressed, a menu opening and closing. Empty:
## silent.
@export var menu_focus_cue_id: StringName = &""
@export var menu_press_cue_id: StringName = &""
@export var menu_open_cue_id: StringName = &""
@export var menu_close_cue_id: StringName = &""
## What a new playthrough or a sequel carries over from the game before it
## (`Playthrough`, `InheritanceRule`); empty carries nothing.
@export var inheritance: Array[InheritanceRule] = []
## The game's input controls, `ControlAction` resources in the order the
## settings list them. The core's own controls (`GameControls.CORE`)
## follow, except one whose action the game lists: the game's control replaces
## it. Typed `Resource` rather than `ControlAction`: on Godot 4.7.2 the typed
## array makes GDScript's shutdown skip scripts (a loop upstream has since
## rewritten), so every test run ends with leak errors.
@export var controls: Array[Resource] = []
## What the game sets for its modules (`ModuleSettings`), at most one of each
## kind; a module whose settings the game does not list takes their defaults.
## Typed `Resource` for the same reason as `controls`.
@export var module_settings: Array[Resource] = []

var _default_calendar: GameCalendar
# Script -> the defaults of a kind of settings the game does not list.
var _default_settings: Dictionary[Script, ModuleSettings] = {}

## The game's calendar, or the default one when it sets none.
func get_calendar() -> GameCalendar:
	if calendar != null:
		return calendar
	if _default_calendar == null:
		_default_calendar = GameCalendar.new()
	return _default_calendar

## The game's settings of the kind `script` (a `ModuleSettings` subclass), or
## that kind's defaults when the game lists none.
func get_settings(script: Script) -> ModuleSettings:
	for entry: Resource in module_settings:
		if entry != null and entry.get_script() == script:
			return entry as ModuleSettings
	if not _default_settings.has(script):
		_default_settings[script] = script.new() as ModuleSettings
	return _default_settings[script]

## Problems with `module_settings`: an entry that is no `ModuleSettings`, a
## kind listed twice, and what the settings of each kind listed or in `kinds`
## (those of the game's modules, `ContentRegistry.register_settings()`) report
## about themselves, the kind's defaults when the game lists none.
func find_settings_problems(registry: ContentRegistry, kinds: Array[Script] = []) -> PackedStringArray:
	var problems := PackedStringArray()
	var checked: Array[Script] = []
	for entry: Resource in module_settings:
		var settings := entry as ModuleSettings
		if settings == null:
			problems.append("the game lists module settings that are no ModuleSettings")
		elif checked.has(settings.get_script()):
			problems.append("the game lists %s twice" % _settings_label(settings.get_script()))
		else:
			checked.append(settings.get_script())
	for script: Script in kinds:
		if not checked.has(script):
			checked.append(script)
	for script: Script in checked:
		for problem: String in get_settings(script).find_problems(registry):
			problems.append("%s: %s" % [_settings_label(script), problem])
	return problems

## Problems with where a new game starts and where a player who passes out
## wakes: the start location must be a location of `registry`, the home
## location too when the game names one, and the home spawn a spawn point of
## the home location.
func find_place_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if start_location_id == &"":
		problems.append("the game names no start location (GameDefinition.start_location_id)")
	elif not registry.has_entry(WorldLocationData.KIND, start_location_id):
		problems.append("the start location '%s' is no location of the game" % start_location_id)
	if home_location_id == &"":
		if home_spawn_id != &"":
			problems.append("the home spawn '%s' belongs to no home location (GameDefinition.home_location_id)" % home_spawn_id)
	elif not registry.has_entry(WorldLocationData.KIND, home_location_id):
		problems.append("the home location '%s' is no location of the game" % home_location_id)
	elif home_spawn_id != &"" and not registry.has_location_spawn(home_location_id, home_spawn_id):
		problems.append("the home spawn '%s' is no spawn point of location '%s'" % [home_spawn_id, home_location_id])
	return problems

static func _settings_label(script: Script) -> String:
	var label := String(script.get_global_name()) if script != null else ""
	return label if not label.is_empty() else "ModuleSettings"
