class_name CoreRules
extends RefCounted

## Condition and action keys of the core (see `GameRulesService`): the world's
## flags, the day, season, weekday, time and weather, where the player is,
## the player's vitals, the playthrough, and the arguments of the event that
## set off a trigger.

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"TRUE", _always.bind(true), 0, 0)
	rules.register_condition(&"FALSE", _always.bind(false), 0, 0)
	rules.register_condition(&"WORLD_FLAG", _world_flag, 1, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_BOOL])
	rules.register_condition(&"FLAG_AT_LEAST", _flag_at_least, 2, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_INT])
	rules.register_condition(&"DAY_AT_LEAST", _day_at_least, 1, 1, [GameRulesService.ARG_INT])
	rules.register_condition(&"DAY_AT_MOST", _day_at_most, 1, 1, [GameRulesService.ARG_INT])
	rules.register_condition(&"SEASON", _season, 1, -1, [GameRulesService.ARG_SEASON])
	rules.register_condition(&"DAY_OF_SEASON", _day_of_season, 1, -1, [GameRulesService.ARG_INT], Callable(), _days_within.bind(&"days_per_season", 1, "day of a season"))
	rules.register_condition(&"WEEKDAY", _weekday, 1, -1, [GameRulesService.ARG_INT], Callable(), _days_within.bind(&"days_per_week", 0, "weekday"))
	rules.register_condition(&"TIME_BETWEEN", _time_between, 2, 2, [GameRulesService.ARG_INT])
	rules.register_condition(&"WEATHER", _weather, 1, -1, [WeatherData.KIND])
	rules.register_condition(&"LOCATION", _location.bind(rules), 1, -1, [WorldLocationData.KIND])
	rules.register_condition(&"REGION", _region.bind(rules), 1, -1, [RegionData.KIND])
	rules.register_condition(&"VITAL_AT_LEAST", _vital_at_least, 2, 2, [VitalData.KIND, GameRulesService.ARG_INT])
	rules.register_condition(&"PLAYTHROUGH_AT_LEAST", _playthrough_at_least, 1, 1, [GameRulesService.ARG_COUNT])
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
