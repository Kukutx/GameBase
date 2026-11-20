class_name CoreRules
extends RefCounted

## Condition and action keys of the core (see `GameRulesService`): the world's
## flags, the day, season, weekday, time and weather, where the player is,
## the player's vitals, the playthrough, the player's options, and the
## arguments of the event that set off a trigger.

## The id of an option of the game (`GameOption`, `GameSettings.options`).
const ARG_OPTION := &"option"

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"TRUE", _always.bind(true), 0, 0)
	rules.register_condition(&"FALSE", _always.bind(false), 0, 0)
	rules.register_condition(&"WORLD_FLAG", _world_flag, 1, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_BOOL])
	rules.register_condition(&"FLAG_AT_LEAST", _flag_at_least, 2, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_INT])
	rules.register_condition(&"DAY_AT_LEAST", _day_at_least, 1, 1, [GameRulesService.ARG_INT], _describe_day_at_least)
	rules.register_condition(&"DAY_AT_MOST", _day_at_most, 1, 1, [GameRulesService.ARG_INT])
	rules.register_condition(&"SEASON", _season, 1, -1, [GameRulesService.ARG_SEASON], _describe_season)
	rules.register_condition(&"DAY_OF_SEASON", _day_of_season, 1, -1, [GameRulesService.ARG_INT], Callable(), _days_within.bind(&"days_per_season", 1, "day of a season"))
	rules.register_condition(&"WEEKDAY", _weekday, 1, -1, [GameRulesService.ARG_INT], Callable(), _days_within.bind(&"days_per_week", 0, "weekday"))
	rules.register_condition(&"TIME_BETWEEN", _time_between, 2, 2, [GameRulesService.ARG_INT])
	rules.register_condition(&"WEATHER", _weather, 1, -1, [WeatherData.KIND], _describe_weather)
	rules.register_condition(&"LOCATION", _location.bind(rules), 1, -1, [WorldLocationData.KIND], _describe_location)
	rules.register_condition(&"REGION", _region.bind(rules), 1, -1, [RegionData.KIND])
	rules.register_condition(&"VITAL_AT_LEAST", _vital_at_least, 2, 2, [VitalData.KIND, GameRulesService.ARG_INT], _describe_vital_at_least)
	rules.register_condition(&"PLAYTHROUGH_AT_LEAST", _playthrough_at_least, 1, 1, [GameRulesService.ARG_COUNT], _describe_playthrough_at_least)
	rules.register_arg_kind(ARG_OPTION, _option_problem)
	rules.register_condition(&"OPTION", _option, 2, -1, [ARG_OPTION, GameRulesService.ARG_TEXT], Callable(), _option_values_problem)
	rules.register_condition(&"OPTION_AT_LEAST", _option_at_least, 2, 2, [ARG_OPTION, GameRulesService.ARG_NUMBER], Callable(), _number_option_problem)
	rules.register_condition(&"MINIGAME_WON", _minigame_won, 1, -1, [MiniGameDefinition.KIND], _describe_minigame_won)
	rules.register_condition(&"MINIGAME_STARS", _minigame_stars, 2, 2, [MiniGameDefinition.KIND, GameRulesService.ARG_COUNT], _describe_minigame_stars, _check_minigame_stars)
	rules.register_condition(&"EVENT_ARG", _event_arg, 2, -1, [GameRulesService.ARG_TEXT])
	rules.register_condition(&"EVENT_ARG_AT_LEAST", _event_arg_at_least, 2, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_NUMBER])
	rules.register_action(&"SET_FLAG", _set_flag, 1, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_FLAG_VALUE])
	rules.register_action(&"CLEAR_FLAG", _clear_flag, 1, 1, [GameRulesService.ARG_TEXT])
	rules.register_action(&"ADD_FLAG", _add_flag, 1, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_INT])
	rules.register_action(&"RESTORE_VITAL", _restore_vital, 2, 2, [VitalData.KIND, GameRulesService.ARG_INT])

## TRUE: always holds.

## FALSE: never holds.
static func _always(_args: PackedStringArray, _context: Dictionary, result: bool) -> bool:
	return result

## WORLD_FLAG <key> [true|false]: the boolean world flag has the value (default true).
static func _world_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	return WorldState.get_bool(StringName(args[0])) == (GameRulesService.to_bool(args[1]) if args.size() > 1 else true)

## FLAG_AT_LEAST <key> <n>: the counter stored under the key is at least n.
static func _flag_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return WorldState.get_int(StringName(args[0])) >= int(args[1])

## DAY_AT_LEAST <n>: the absolute day number is at least n.
static func _day_at_least(args: PackedStringArray, context: Dictionary) -> bool:
	return GameRulesService.context_day(context) >= int(args[0])

## DAY_AT_MOST <n>: the absolute day number is at most n.
static func _day_at_most(args: PackedStringArray, context: Dictionary) -> bool:
	return GameRulesService.context_day(context) <= int(args[0])

## SEASON <name>...: the season is one of the names (the calendar's seasons).
static func _season(args: PackedStringArray, context: Dictionary) -> bool:
	return args.has(GameCalendar.current().get_season_name(GameRulesService.context_day(context)))

## DAY_OF_SEASON <n>...: the day within the season (from 1) is one of the numbers.
static func _day_of_season(args: PackedStringArray, context: Dictionary) -> bool:
	return args.has(str(GameCalendar.current().get_day_of_season(GameRulesService.context_day(context))))

## WEEKDAY <n>...: the weekday is one of the numbers; day 1 is weekday 0.
static func _weekday(args: PackedStringArray, context: Dictionary) -> bool:
	return args.has(str(GameCalendar.current().get_weekday(GameRulesService.context_day(context))))

# The numbers are days the calendar has: from `first` to the calendar's
# `count_property` (counted from `first`).
static func _days_within(args: PackedStringArray, count_property: StringName, first: int, label: String) -> String:
	var last := first + int(GameCalendar.current().get(count_property)) - 1
	for arg: String in args:
		if int(arg) < first or int(arg) > last:
			return "%s is not a %s (%d-%d)" % [arg, label, first, last]
	return ""

## TIME_BETWEEN <from> <to>: the minute of the day is in [from, to).
static func _time_between(args: PackedStringArray, context: Dictionary) -> bool:
	var minute := GameRulesService.context_minute(context)
	return minute >= int(args[0]) and minute < int(args[1])

## WEATHER <weather>...: the day's weather is one of them (`WeatherData`).
static func _weather(args: PackedStringArray, context: Dictionary) -> bool:
	return args.has(String(WeatherState.get_weather_id(GameRulesService.context_day(context))))

## LOCATION <id>...: the player is in one of the locations.
static func _location(args: PackedStringArray, context: Dictionary, rules: GameRulesService) -> bool:
	var location_id := String(context.get("location_id", ""))
	if location_id.is_empty():
		var current := WorldLocationData.find_current(rules.get_tree())
		location_id = String(current.id) if current != null else ""
	return args.has(location_id)

## REGION <region>...: the player (or the context's "location_id") is in a
## location of one of the regions.
static func _region(args: PackedStringArray, context: Dictionary, rules: GameRulesService) -> bool:
	var location: WorldLocationData = null
	if context.has("location_id"):
		location = WorldLocationData.find(StringName(String(context["location_id"])))
	else:
		location = WorldLocationData.find_current(rules.get_tree())
	return location != null and args.has(String(location.region_id))

## VITAL_AT_LEAST <vital> <n>: the player has at least n of the vital.
static func _vital_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return Vitals.get_value(StringName(args[0])) >= int(args[1])

## PLAYTHROUGH_AT_LEAST <n>: this is the nth playthrough or a later one
## (`Playthrough`; new game plus).
static func _playthrough_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return Playthrough.get_playthrough() >= int(args[0])

## MINIGAME_WON <minigame>...: the player won each of the minigames in this
## save (`MiniGameHost` counts the wins).
static func _minigame_won(args: PackedStringArray, _context: Dictionary) -> bool:
	for minigame_id: String in args:
		if WorldState.get_int(MiniGameDefinition.wins_key(StringName(minigame_id))) <= 0:
			return false
	return true

static func _describe_minigame_won(args: PackedStringArray) -> String:
	return TranslationServer.translate("Win %s") % _names(MiniGameDefinition.KIND, args)

## MINIGAME_STARS <minigame> <count>: the player's best score of the
## minigame, in any save, has earned at least `count` of its stars
## (`MiniGameDefinition.score_goals`).
static func _minigame_stars(args: PackedStringArray, _context: Dictionary) -> bool:
	var definition := MiniGameDefinition.find(StringName(args[0]))
	return definition != null and definition.get_stars() >= int(args[1])

static func _describe_minigame_stars(args: PackedStringArray) -> String:
	return TranslationServer.translate("%d stars at %s") % [int(args[1]), _names(MiniGameDefinition.KIND, args.slice(0, 1))]

static func _check_minigame_stars(args: PackedStringArray) -> String:
	var definition := MiniGameDefinition.find(StringName(args[0]))
	var goals := definition.score_goals.size()
	if int(args[1]) <= goals:
		return ""
	return "minigame '%s' has %d stars to earn, not %d" % [args[0], goals, int(args[1])]

static func _describe_day_at_least(args: PackedStringArray) -> String:
	return TranslationServer.translate("From day %d") % int(args[0])

static func _describe_season(args: PackedStringArray) -> String:
	var names := PackedStringArray()
	for season: String in args:
		names.append(TranslationServer.translate(season))
	return TranslationServer.translate("In %s") % " / ".join(names)

static func _describe_vital_at_least(args: PackedStringArray) -> String:
	return "%s %d" % [GameRulesService.entry_name(VitalData.KIND, args[0]), int(args[1])]

static func _describe_playthrough_at_least(args: PackedStringArray) -> String:
	return TranslationServer.translate("Playthrough %d") % int(args[0])

static func _describe_weather(args: PackedStringArray) -> String:
	return TranslationServer.translate("When it is %s") % _names(WeatherData.KIND, args, " / ")

static func _describe_location(args: PackedStringArray) -> String:
	return TranslationServer.translate("At %s") % _names(WorldLocationData.KIND, args, " / ")

# The names of the entries of `kind` the arguments name, between `separator`:
# "A, B" for each of them, "A / B" for one of them.
static func _names(kind: StringName, args: PackedStringArray, separator := ", ") -> String:
	var names := PackedStringArray()
	for entry_id: String in args:
		names.append(GameRulesService.entry_name(kind, entry_id))
	return separator.join(names)

## OPTION <option> <value>...: the player's option (`GameOption`) is one of
## the values: true or false for a switch, a choice's name (in quotes with a
## space: "Very Hard"), a number for a range.
static func _option(args: PackedStringArray, _context: Dictionary) -> bool:
	var option := GameSettings.options.find(StringName(args[0]))
	if option == null:
		return false
	var value: Variant = GameSettings.get_option(option.id)
	for text: String in args.slice(1):
		var wanted: Variant = _option_value(option, text)
		if wanted != null and wanted == value:
			return true
	return false

## OPTION_AT_LEAST <option> <n>: the player's number option is at least n.
static func _option_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	var option := GameSettings.options.find(StringName(args[0]))
	return option != null and option.kind == GameOption.Kind.RANGE and float(GameSettings.get_option(option.id)) >= float(args[1])

# `text` as a value of `option`, or null when the option takes no such value.
static func _option_value(option: GameOption, text: String) -> Variant:
	match option.kind:
		GameOption.Kind.SWITCH:
			return GameRulesService.to_bool(text) if ["true", "false"].has(text.to_lower()) else null
		GameOption.Kind.CHOICE:
			return text if option.choices.has(text) else null
	return option.accept(float(text), null) if text.is_valid_float() else null

static func _option_problem(id: String) -> String:
	return "" if GameSettings.options.find(StringName(id)) != null else "no option '%s' of the game (GameDefinition.options, GameModule.get_options())" % id

static func _option_values_problem(args: PackedStringArray) -> String:
	var option := GameSettings.options.find(StringName(args[0]))
	for text: String in args.slice(1):
		if not text.begins_with("$") and _option_value(option, text) == null:
			return "'%s' is no value of option '%s'" % [text, option.id]
	return ""

static func _number_option_problem(args: PackedStringArray) -> String:
	var option := GameSettings.options.find(StringName(args[0]))
	return "" if option.kind == GameOption.Kind.RANGE else "option '%s' is no number" % option.id

## EVENT_ARG <name> <value>...: the argument of the event that set off the
## trigger is one of the values (see `TriggerData`).
static func _event_arg(args: PackedStringArray, context: Dictionary) -> bool:
	var event: Dictionary = context.get("event", {})
	return event.has(args[0]) and args.slice(1).has(str(event[args[0]]))

## EVENT_ARG_AT_LEAST <name> <n>: that argument is a number of at least n.
static func _event_arg_at_least(args: PackedStringArray, context: Dictionary) -> bool:
	var value: Variant = (context.get("event", {}) as Dictionary).get(args[0])
	return (value is int or value is float) and float(value) >= float(args[1])

## SET_FLAG <key> [value]: value is true, false or an integer (default true).
static func _set_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	var value: Variant = true
	if args.size() > 1:
		value = int(args[1]) if args[1].is_valid_int() else GameRulesService.to_bool(args[1])
	WorldState.set_value(StringName(args[0]), value)
	return true

## CLEAR_FLAG <key>: removes the value stored under the key, so a flag reads as
## false and a counter as 0; never fails.
static func _clear_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	WorldState.erase(StringName(args[0]))
	return true

## ADD_FLAG <key> [n]: adds n (default 1) to the counter stored under the key.
static func _add_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	WorldState.add_int(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)
	return true

## RESTORE_VITAL <vital> <n>: restores n of the vital, up to its maximum; an
## n of 0 or less restores nothing, and the action still succeeds.
static func _restore_vital(args: PackedStringArray, _context: Dictionary) -> bool:
	Vitals.restore(StringName(args[0]), int(args[1]))
	return true
