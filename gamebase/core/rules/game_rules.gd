class_name GameRulesService
extends Node

## Registry of the conditions and actions content can name in text.
##
## Content describes when something is available (`condition`) and what it does
## (`actions`) with short text keys instead of code, so a module adds a new kind
## of check once and every content type can use it (see `GameQuery` for the
## syntax). Each module registers its keys; `validate_content()` reports every
## key content uses that nothing registered, so a typo fails validation instead
## of silently never matching.
##
## Conditions are `func(args: PackedStringArray, context: Dictionary) -> bool`;
## actions are `func(args: PackedStringArray, context: Dictionary) -> bool`
## returning whether they succeeded. `context` carries optional facts of the
## caller, such as "day" when a condition is asked about another day.
## A condition may also register a `describer`, `func(args: PackedStringArray) -> String`:
## the requirement in words a player reads, which `describe()` collects so a
## menu can say what a locked entry needs.
##
## In a trigger's condition and actions an argument written `$name` is the
## argument `name` of the event that set the trigger off (the context's
## "event"; see `TriggerData`): `ADD_SKILL_XP combat $combat_xp`.

## Argument checks for `register_condition`/`register_action` `arg_kinds`: a
## content kind (checked against the running game's content,
## `ContentRegistry.active`), a kind a module registers with
## `register_arg_kind()`, or one of these value kinds.
const ARG_INT := &"int"
const ARG_NUMBER := &"number"
const ARG_BOOL := &"bool"
const ARG_TEXT := &"text"

var _conditions: Dictionary = {}
var _actions: Dictionary = {}
## kind -> Callable(value: String) -> String
var _arg_kinds: Dictionary = {}
var _parsed: Dictionary = {}

func _ready() -> void:
	_register_core_rules()

## Registers a condition key. `min_args`/`max_args` bound the argument count
## (-1: unbounded); `arg_kinds[i]` checks argument i (the last kind repeats).
## `args_check`, `func(args: PackedStringArray) -> String`, returns what is
## wrong with the arguments together (a level the named skill cannot reach),
## or ""; validation calls it once the count and every argument passed.
func register_condition(key: StringName, evaluate: Callable, min_args := 0, max_args := -1, arg_kinds: Array[StringName] = [], describer := Callable(), args_check := Callable()) -> void:
	_conditions[_normalize(key)] = {"call": evaluate, "min": min_args, "max": max_args, "kinds": arg_kinds, "describer": describer, "args_check": args_check}

## Registers an action key; the arguments are checked as a condition's are.
func register_action(key: StringName, run: Callable, min_args := 0, max_args := -1, arg_kinds: Array[StringName] = [], args_check := Callable()) -> void:
	_actions[_normalize(key)] = {"call": run, "min": min_args, "max": max_args, "kinds": arg_kinds, "args_check": args_check}

## Registers an argument kind for `arg_kinds`. `check` is
## `func(value: String) -> String` returning what is wrong with `value`, or "".
func register_arg_kind(kind: StringName, check: Callable) -> void:
	_arg_kinds[kind] = check

func has_condition(key: StringName) -> bool:
	return _conditions.has(_normalize(key))

func has_action(key: StringName) -> bool:
	return _actions.has(_normalize(key))

func get_condition_keys() -> PackedStringArray:
	return _sorted_keys(_conditions)

func get_action_keys() -> PackedStringArray:
	return _sorted_keys(_actions)

## True when every clause of `query` holds. An empty query is true; a query
## that does not parse or names an unknown key is false.
func check(query: String, context: Dictionary = {}) -> bool:
	var parsed := _parse(query)
	if not String(parsed["error"]).is_empty():
		return false
	for clause: Dictionary in parsed["clauses"]:
		if _evaluate_clause(clause, context) == bool(clause["negate"]):
			return false
	return true

## What `query` requires, in words a player reads: the description of each
## clause whose condition registered one. Negated clauses and conditions
## without a description are left out.
func describe(query: String) -> PackedStringArray:
	var result := PackedStringArray()
	var parsed := _parse(query)
	if not String(parsed["error"]).is_empty():
		return result
	for clause: Dictionary in parsed["clauses"]:
		var describer: Callable = (_conditions.get(clause["key"], {}) as Dictionary).get("describer", Callable())
		if not bool(clause["negate"]) and describer.is_valid():
			result.append(String(describer.call(clause["args"])))
	return result

## Runs each action in order and stops at the first one that fails. Returns
## whether all succeeded.
func run_actions(actions: PackedStringArray, context: Dictionary = {}) -> bool:
	for action_text: String in actions:
		var parsed := _parse(action_text)
		if not String(parsed["error"]).is_empty():
			push_error("GameRules: %s" % parsed["error"])
			return false
		for clause: Dictionary in parsed["clauses"]:
			var entry: Dictionary = _actions.get(clause["key"], {})
			if entry.is_empty():
				push_error("GameRules: unknown action '%s'" % clause["key"])
				return false
			if not bool((entry["call"] as Callable).call(_resolve_args(clause["args"], context), context)):
				return false
	return true

## Problems with `query`: parse errors, unknown keys, argument counts and kinds.
func validate_query(query: String) -> PackedStringArray:
	return _validate(query, _conditions, "condition", true)

func validate_actions(actions: PackedStringArray) -> PackedStringArray:
	var problems := PackedStringArray()
	for action_text: String in actions:
		problems.append_array(_validate(action_text, _actions, "action", false))
	return problems

## Validates every `condition`, `*_condition`, `actions` and `*_actions` property of every
## entry in `registry`, including resources nested in arrays.
func validate_content(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for kind: StringName in registry.get_kinds():
		for entry: Variant in registry.get_entries(kind):
			if entry is Resource:
				_validate_resource(entry as Resource, "%s '%s'" % [kind, (entry as Resource).get("id")], problems, 0)
	return problems

func _validate_resource(resource: Resource, context: String, problems: PackedStringArray, depth: int) -> void:
	if depth > 4:
		return
	for property: Dictionary in resource.get_property_list():
		if not int(property["usage"]) & PROPERTY_USAGE_STORAGE:
			continue
		var name := String(property["name"])
		var value: Variant = resource.get(name)
		if (name == "condition" or name.ends_with("_condition")) and value is String:
			for problem: String in validate_query(value):
				problems.append("%s %s: %s" % [context, name, problem])
			if not resource is TriggerData and not find_event_arg_uses(PackedStringArray([value])).is_empty():
				problems.append("%s %s: only a trigger's conditions and actions name event arguments ($name)" % [context, name])
		elif (name == "actions" or name.ends_with("_actions")) and (value is PackedStringArray or value is Array):
			for problem: String in validate_actions(PackedStringArray(value)):
				problems.append("%s %s: %s" % [context, name, problem])
			if not resource is TriggerData and not find_event_arg_uses(PackedStringArray(value)).is_empty():
				problems.append("%s %s: only a trigger's conditions and actions name event arguments ($name)" % [context, name])
		elif value is Array:
			for item: Variant in value:
				if item is Resource and not (item as Resource).resource_path.ends_with(".tres"):
					_validate_resource(item as Resource, "%s %s" % [context, name], problems, depth + 1)

func _validate(text: String, registry: Dictionary, label: String, allow_negate: bool) -> PackedStringArray:
	var problems := PackedStringArray()
	var parsed := GameQuery.parse(text)
	if not String(parsed["error"]).is_empty():
		problems.append(parsed["error"])
		return problems
	for clause: Dictionary in parsed["clauses"]:
		var key: StringName = clause["key"]
		var args: PackedStringArray = clause["args"]
		if bool(clause["negate"]) and not allow_negate:
			problems.append("%s '%s' cannot be negated" % [label, key])
		if key == &"ANY" and allow_negate:
			for sub_query: String in args:
				problems.append_array(_validate(sub_query, registry, label, allow_negate))
			continue
		var entry: Dictionary = registry.get(key, {})
		if entry.is_empty():
			problems.append("unknown %s '%s'" % [label, key])
			continue
		var found := problems.size()
		var min_args := int(entry["min"])
		var max_args := int(entry["max"])
		if args.size() < min_args or (max_args >= 0 and args.size() > max_args):
			problems.append("%s '%s' takes %s arguments, got %d" % [label, key, _arg_range(min_args, max_args), args.size()])
		var kinds: Array[StringName] = entry["kinds"]
		for index: int in args.size():
			if kinds.is_empty():
				break
			var problem := _check_arg(args[index], kinds[mini(index, kinds.size() - 1)])
			if not problem.is_empty():
				problems.append("%s '%s' argument %d: %s" % [label, key, index + 1, problem])
		var args_check: Callable = entry["args_check"]
		# An event argument has no value yet to check together with the others.
		if problems.size() == found and args_check.is_valid() and not _names_event_arg(args):
			var problem := String(args_check.call(args))
			if not problem.is_empty():
				problems.append("%s '%s': %s" % [label, key, problem])
	return problems

func _check_arg(value: String, kind: StringName) -> String:
	if value.begins_with("$"):
		return "" if value.substr(1).is_valid_ascii_identifier() else "'%s' is not an event argument ($name)" % value
	match kind:
		ARG_INT:
			return "" if value.is_valid_int() else "'%s' is not an integer" % value
		ARG_NUMBER:
			return "" if value.is_valid_float() else "'%s' is not a number" % value
		ARG_BOOL:
			return "" if ["true", "false"].has(value.to_lower()) else "'%s' is not true or false" % value
		ARG_TEXT:
			return ""
	if _arg_kinds.has(kind):
		return String((_arg_kinds[kind] as Callable).call(value))
	return "" if ContentRegistry.active.has_entry(kind, StringName(value)) else "unknown %s '%s'" % [kind, value]

func _evaluate_clause(clause: Dictionary, context: Dictionary) -> bool:
	var key: StringName = clause["key"]
	var args: PackedStringArray = clause["args"]
	if key == &"ANY":
		for sub_query: String in args:
			if check(sub_query, context):
				return true
		return false
	var entry: Dictionary = _conditions.get(key, {})
	if entry.is_empty():
		return false
	return bool((entry["call"] as Callable).call(_resolve_args(args, context), context))

func _parse(text: String) -> Dictionary:
	if not _parsed.has(text):
		var parsed := GameQuery.parse(text)
		for clause: Dictionary in parsed["clauses"]:
			if clause["key"] != &"ANY" and not _conditions.has(clause["key"]) and not _actions.has(clause["key"]):
				parsed["error"] = "unknown key '%s'" % clause["key"]
		# Unknown keys are not cached: a module may register them later.
		if not String(parsed["error"]).begins_with("unknown key"):
			_parsed[text] = parsed
		return parsed
	return _parsed[text]

func _normalize(key: StringName) -> StringName:
	return StringName(String(key).to_upper())

func _arg_range(min_args: int, max_args: int) -> String:
	if max_args < 0:
		return "at least %d" % min_args
	if min_args == max_args:
		return str(min_args)
	return "%d-%d" % [min_args, max_args]

func _sorted_keys(source: Dictionary) -> PackedStringArray:
	var keys := PackedStringArray()
	for key: StringName in source:
		keys.append(String(key))
	keys.sort()
	return keys

## Each place `texts`, conditions or actions, read an argument of the event
## that set off a trigger, as {"name", "key", "index"}: `index` is where the
## `$name` stands among the key's arguments, or -1 for the name `EVENT_ARG` and
## `EVENT_ARG_AT_LEAST` read. The clauses inside `ANY` count too.
static func find_event_arg_uses(texts: PackedStringArray) -> Array[Dictionary]:
	var uses: Array[Dictionary] = []
	for text: String in texts:
		for clause: Dictionary in GameQuery.parse(text)["clauses"]:
			var key := StringName(String(clause["key"]).to_upper())
			var args: PackedStringArray = clause["args"]
			if key == &"ANY":
				uses.append_array(find_event_arg_uses(args))
				continue
			if (key == &"EVENT_ARG" or key == &"EVENT_ARG_AT_LEAST") and not args.is_empty():
				uses.append({"name": args[0], "key": key, "index": -1})
			for index: int in args.size():
				if args[index].begins_with("$"):
					uses.append({"name": args[index].substr(1), "key": key, "index": index})
	return uses

## The kind of argument `key` takes at `index` (see `register_condition`), or
## &"" when nothing checks it.
func get_arg_kind(key: StringName, index: int) -> StringName:
	var entry: Dictionary = _conditions.get(_normalize(key), _actions.get(_normalize(key), {}))
	var kinds: Array = entry.get("kinds", [])
	return &"" if kinds.is_empty() else StringName(kinds[mini(index, kinds.size() - 1)])

## Whether an event argument of the Variant `type` can stand for an argument
## of `kind`: a number for a number, text or an id for text or an id. An
## untyped event argument can stand for any.
static func takes_type(kind: StringName, type: int) -> bool:
	if type == TYPE_NIL or kind == &"" or kind == ARG_TEXT:
		return true
	match kind:
		ARG_INT:
			return type == TYPE_INT
		ARG_NUMBER:
			return type == TYPE_INT or type == TYPE_FLOAT
		ARG_BOOL:
			return type == TYPE_BOOL
	return type == TYPE_STRING_NAME or type == TYPE_STRING

static func _names_event_arg(args: PackedStringArray) -> bool:
	for arg: String in args:
		if arg.begins_with("$"):
			return true
	return false

# `args` with each `$name` replaced by that argument of the context's event.
static func _resolve_args(args: PackedStringArray, context: Dictionary) -> PackedStringArray:
	var event: Dictionary = context.get("event", {})
	if event.is_empty():
		return args
	var resolved := args.duplicate()
	for index: int in resolved.size():
		if resolved[index].begins_with("$") and event.has(resolved[index].substr(1)):
			resolved[index] = str(event[resolved[index].substr(1)])
	return resolved

## The day a condition is asked about: the context's "day", or today.
static func context_day(context: Dictionary) -> int:
	return int(context.get("day", WorldClock.day))

## The minute of the day a condition is asked about: the context's
## "minute_of_day", or now.
static func context_minute(context: Dictionary) -> int:
	return int(context.get("minute_of_day", WorldClock.minute_of_day))

static func to_bool(value: String) -> bool:
	return value.to_lower() == "true"

func _register_core_rules() -> void:
	register_condition(&"TRUE", _always.bind(true), 0, 0)
	register_condition(&"FALSE", _always.bind(false), 0, 0)
	register_condition(&"WORLD_FLAG", _world_flag, 1, 2, [ARG_TEXT, ARG_BOOL])
	register_condition(&"FLAG_AT_LEAST", _flag_at_least, 2, 2, [ARG_TEXT, ARG_INT])
	register_condition(&"DAY_AT_LEAST", _day_at_least, 1, 1, [ARG_INT])
	register_condition(&"DAY_AT_MOST", _day_at_most, 1, 1, [ARG_INT])
	register_condition(&"SEASON", _season, 1, -1, [ARG_TEXT])
	register_condition(&"DAY_OF_SEASON", _day_of_season, 1, -1, [ARG_INT])
	register_condition(&"WEEKDAY", _weekday, 1, -1, [ARG_INT])
	register_condition(&"TIME_BETWEEN", _time_between, 2, 2, [ARG_INT])
	register_condition(&"WEATHER", _weather, 1, -1, [ARG_TEXT])
	register_condition(&"LOCATION", _location, 1, -1, [WorldLocationData.KIND])
	register_condition(&"MONEY_AT_LEAST", _money_at_least, 1, 1, [ARG_INT])
	register_condition(&"EVENT_ARG", _event_arg, 2, -1, [ARG_TEXT])
	register_condition(&"EVENT_ARG_AT_LEAST", _event_arg_at_least, 2, 2, [ARG_TEXT, ARG_NUMBER])
	register_action(&"SET_FLAG", _set_flag, 1, 2, [ARG_TEXT])
	register_action(&"CLEAR_FLAG", _clear_flag, 1, 1, [ARG_TEXT])
	register_action(&"ADD_FLAG", _add_flag, 1, 2, [ARG_TEXT, ARG_INT])
	register_action(&"ADD_MONEY", _add_money, 1, 1, [ARG_INT])

func _always(_args: PackedStringArray, _context: Dictionary, result: bool) -> bool:
	return result

## WORLD_FLAG <key> [true|false]: the boolean world flag has the value (default true).
func _world_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	return WorldState.get_bool(StringName(args[0])) == (to_bool(args[1]) if args.size() > 1 else true)

## FLAG_AT_LEAST <key> <n>: the counter stored under the key is at least n.
func _flag_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return WorldState.get_int(StringName(args[0])) >= int(args[1])

## DAY_AT_LEAST <n>: the absolute day number is at least n.
func _day_at_least(args: PackedStringArray, context: Dictionary) -> bool:
	return context_day(context) >= int(args[0])

## DAY_AT_MOST <n>: the absolute day number is at most n.
func _day_at_most(args: PackedStringArray, context: Dictionary) -> bool:
	return context_day(context) <= int(args[0])

## SEASON <name>...: the season is one of the names (Spring, Summer, Autumn, Winter).
func _season(args: PackedStringArray, context: Dictionary) -> bool:
	return args.has(GameClock.get_season_name_for_day(context_day(context)))

## DAY_OF_SEASON <n>...: the day within the season (1-28) is one of the numbers.
func _day_of_season(args: PackedStringArray, context: Dictionary) -> bool:
	return args.has(str(posmod(context_day(context) - 1, GameClock.DAYS_PER_SEASON) + 1))

## WEEKDAY <0-6>...: the weekday is one of the numbers; day 1 is weekday 0.
func _weekday(args: PackedStringArray, context: Dictionary) -> bool:
	return args.has(str(posmod(maxi(context_day(context), 1) - 1, 7)))

## TIME_BETWEEN <from> <to>: the minute of the day is in [from, to).
func _time_between(args: PackedStringArray, context: Dictionary) -> bool:
	var minute := context_minute(context)
	return minute >= int(args[0]) and minute < int(args[1])

## WEATHER <name>...: the day's weather is one of the names (Clear, Rain, Storm).
func _weather(args: PackedStringArray, context: Dictionary) -> bool:
	return args.has(WeatherState.get_weather_name(WeatherState.get_weather_for_day(context_day(context))))

## LOCATION <id>...: the player is in one of the locations.
func _location(args: PackedStringArray, context: Dictionary) -> bool:
	var location_id := String(context.get("location_id", ""))
	if location_id.is_empty():
		var current := WorldLocationData.find_current(get_tree())
		location_id = String(current.id) if current != null else ""
	return args.has(location_id)

## MONEY_AT_LEAST <n>
func _money_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return PlayerState.money >= int(args[0])

## EVENT_ARG <name> <value>...: the argument of the event that set off the
## trigger is one of the values (see `TriggerData`).
func _event_arg(args: PackedStringArray, context: Dictionary) -> bool:
	var event: Dictionary = context.get("event", {})
	return event.has(args[0]) and args.slice(1).has(str(event[args[0]]))

## EVENT_ARG_AT_LEAST <name> <n>: that argument is a number of at least n.
func _event_arg_at_least(args: PackedStringArray, context: Dictionary) -> bool:
	var value: Variant = (context.get("event", {}) as Dictionary).get(args[0])
	return (value is int or value is float) and float(value) >= float(args[1])

## SET_FLAG <key> [value]: value is true, false or an integer (default true).
func _set_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	var value: Variant = true
	if args.size() > 1:
		value = int(args[1]) if args[1].is_valid_int() else to_bool(args[1])
	WorldState.set_value(StringName(args[0]), value)
	return true

## CLEAR_FLAG <key>
func _clear_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	WorldState.erase(StringName(args[0]))
	return true

## ADD_FLAG <key> [n]: adds n (default 1) to the counter stored under the key.
func _add_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	WorldState.add_int(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)
	return true

## ADD_MONEY <n>
func _add_money(args: PackedStringArray, _context: Dictionary) -> bool:
	PlayerState.add_money(int(args[0]))
	return true
