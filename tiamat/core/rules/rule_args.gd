class_name RuleArgs
extends RefCounted

## The arguments of the conditions and actions content names (`GameRules`):
## what a value of each argument kind may be, the kinds the modules register
## (`register()`), and what a clause's cross-argument check makes of the
## arguments an event gives (`$name`, see `check_with_any_event_values()`).
## The rules service keeps one.

# kind -> Callable(value: String) -> String
var _kinds: Dictionary = {}

## Registers an argument kind. `check` is `func(value: String) -> String`
## returning what is wrong with `value`, or "".
func register(kind: StringName, check: Callable) -> void:
	_kinds[kind] = check

## The kind of argument `index` among `kinds` (the last kind repeats), or &""
## when nothing checks it.
static func kind_at(kinds: Array, index: int) -> StringName:
	return &"" if kinds.is_empty() else StringName(kinds[mini(index, kinds.size() - 1)])

## Whether any of `args` names an event's argument (`$name`).
static func names_event_arg(args: PackedStringArray) -> bool:
	for arg: String in args:
		if arg.begins_with("$"):
			return true
	return false

## What is wrong with `value` as written for an argument of `kind`, or "":
## `$name` stands for the event's argument `name`, checked when it fires.
func check_written(value: String, kind: StringName) -> String:
	if value.begins_with("$"):
		return "" if value.substr(1).is_valid_ascii_identifier() else "'%s' is not an event argument ($name)" % value
	return check(value, kind)

## What is wrong with `value` as an argument of `kind`, or "": a value kind
## (`GameRulesService.ARG_INT` and the others), a registered kind, or else a
## content kind whose entries the value names.
func check(value: String, kind: StringName) -> String:
	match kind:
		GameRulesService.ARG_INT:
			return "" if value.is_valid_int() else "'%s' is not an integer" % value
		GameRulesService.ARG_NUMBER:
			return "" if value.is_valid_float() else "'%s' is not a number" % value
		GameRulesService.ARG_COUNT:
			return "" if value.is_valid_int() and int(value) >= 1 else "'%s' is not a count (a whole number of at least 1)" % value
		GameRulesService.ARG_BOOL:
			return "" if ["true", "false"].has(value.to_lower()) else "'%s' is not true or false" % value
		GameRulesService.ARG_TEXT:
			return ""
		GameRulesService.ARG_SEASON:
			return "" if GameCalendar.current().has_season(value) else "unknown season '%s'" % value
		GameRulesService.ARG_FLAG_VALUE:
			return "" if value.is_valid_int() or ["true", "false"].has(value.to_lower()) else "'%s' is not true, false or an integer" % value
	if _kinds.has(kind):
		return String((_kinds[kind] as Callable).call(value))
	return "" if ContentRegistry.active.has_entry(kind, StringName(value)) else "unknown %s '%s'" % [kind, value]

## Every value an argument of `kind` can take, when they can be listed: true
## and false, the calendar's seasons, or the ids of a content kind that pass
## its check; empty when they cannot.
func values_of(kind: StringName) -> PackedStringArray:
	var values := PackedStringArray()
	if kind == GameRulesService.ARG_BOOL:
		return PackedStringArray(["true", "false"])
	if kind == GameRulesService.ARG_SEASON:
		return GameCalendar.current().season_names.duplicate()
	if kind in [&"", GameRulesService.ARG_INT, GameRulesService.ARG_NUMBER, GameRulesService.ARG_TEXT, GameRulesService.ARG_COUNT, GameRulesService.ARG_FLAG_VALUE]:
		return values
	# A kind registered with its own check may still name content (a skill):
	# its values are the entries that pass that check.
	for entry: Variant in ContentRegistry.active.get_entries(kind):
		if entry is ContentEntry:
			var id := String((entry as ContentEntry).id)
			if check(id, kind).is_empty():
				values.append(id)
	return values

## What `args_check` finds wrong with `args` (arguments of `kinds`) for every
## value their event arguments can take, or "" when one passes. An argument
## whose values cannot be listed (a number, text), or more than
## `GameRulesService.MAX_EVENT_ARG_VALUES` together, leave the check to the
## event.
func check_with_any_event_values(args_check: Callable, args: PackedStringArray, kinds: Array) -> String:
	var choices: Array[PackedStringArray] = []
	var combinations := 1
	for index: int in args.size():
		if not args[index].begins_with("$"):
			choices.append(PackedStringArray([args[index]]))
			continue
		var values := values_of(kind_at(kinds, index))
		combinations *= values.size()
		if values.is_empty() or combinations > GameRulesService.MAX_EVENT_ARG_VALUES:
			return ""
		choices.append(values)
	var first_problem := ""
	var picked: Array[int] = []
	picked.resize(choices.size())
	picked.fill(0)
	for _combination: int in combinations:
		var candidate := PackedStringArray()
		for index: int in choices.size():
			candidate.append(choices[index][picked[index]])
		var problem := String(args_check.call(candidate))
		if problem.is_empty():
			return ""
		if first_problem.is_empty():
			first_problem = problem
		# The next combination, the last argument turning fastest.
		for index: int in range(choices.size() - 1, -1, -1):
			picked[index] += 1
			if picked[index] < choices[index].size():
				break
			picked[index] = 0
	return first_problem
