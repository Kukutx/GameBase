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
## Location the player is brought back to after collapsing or staying up too late.
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
## Seed of a new game's world randomness (`GameRandom`): the weather, catches,
## mine floors and more. 0 gives each new game a fresh seed.
@export var world_seed := 0
## The odds of rain and storms in each season (`GameWeatherSystem`); a season
## missing here is always clear.
@export var weather_odds: Array[WeatherOdds] = []
## Items granted at the start of a new game, as item id → amount.
@export var start_items: Dictionary[StringName, int] = {}
## Audio cue played for an event, as `<Autoload>.<signal>`
## (`LifesimEvents.crop_harvested`) → cue id.
@export var event_cues: Dictionary[StringName, StringName] = {}
## Starting money and hotbar of a new game (item ids; empty for a free slot).
@export_range(0, 999999) var start_money := 500
@export var start_hotbar: Array[StringName] = []
## The game's UI theme; module menus apply it to their panels (none: Godot's default).
@export var ui_theme: Theme
## The game's input controls, `ControlAction` resources in the order the
## settings list them. The core's own controls (`GameSettingsService.CORE_CONTROLS`)
## follow, except one whose action the game lists: the game's control replaces
## it. Typed `Resource` rather than `ControlAction`: on Godot 4.7.2 the typed
## array makes GDScript's shutdown skip scripts (a loop upstream has since
## rewritten), so every test run ends with leak errors.
@export var controls: Array[Resource] = []

var _default_calendar: GameCalendar

## The game's calendar, or the default one when it sets none.
func get_calendar() -> GameCalendar:
	if calendar != null:
		return calendar
	if _default_calendar == null:
		_default_calendar = GameCalendar.new()
	return _default_calendar
