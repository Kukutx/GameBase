class_name GameOption
extends Resource

## A choice of the player's that a game or a module adds to the settings
## (`GameOptions`): a switch, one of a few named choices, or a number in a
## range. The game lists its own in `GameDefinition.options` and a module
## declares those of its systems (`GameModule.get_options()`: the dialogue
## module's auto-advance); `GameSettings` keeps the player's value with the
## rest of the settings (`get_option()`, `set_option()`, `option_changed`), and
## the settings menu shows a row for each, under the game's options.
##
## A system reads its option where it acts, not as it starts, so a change the
## player makes in the menu holds at once.

## How the player sets the option.
enum Kind {
	## On or off (`default_on`).
	SWITCH,
	## One of `choices` (`default_choice`).
	CHOICE,
	## A number from `min_value` to `max_value` in steps of `step`
	## (`default_number`).
	RANGE,
}

## The option's name in the settings file and in code: `get_option(id)`.
@export var id: StringName = &""
## The option's name in the settings, translated by the catalog of the layer
## that declares it.
@export var display_name := ""
@export var kind := Kind.SWITCH
@export var default_on := false
## The choices, as the settings show them (translated like `display_name`) and
## as the settings file and `get_option()` hold them.
@export var choices: PackedStringArray = []
@export var default_choice := 0
@export var min_value := 0.0
@export var max_value := 1.0
## The smallest change of a range; 0 for any.
@export var step := 0.1
@export var default_number := 0.5

## A switch `option_id`, shown as `label`, on or off at first.
static func new_switch(option_id: StringName, label: String, on := false) -> GameOption:
	var option := _named(option_id, label)
	option.kind = Kind.SWITCH
	option.default_on = on
	return option

## A choice `option_id`, shown as `label`, among `names`, the one at
## `default_index` at first.
static func new_choice(option_id: StringName, label: String, names: PackedStringArray, default_index := 0) -> GameOption:
	var option := _named(option_id, label)
	option.kind = Kind.CHOICE
	option.choices = names
	option.default_choice = default_index
	return option

## A number `option_id`, shown as `label`, from `low` to `high` in steps of
## `by`, `value` at first.
static func new_range(option_id: StringName, label: String, low: float, high: float, by: float, value: float) -> GameOption:
	var option := _named(option_id, label)
	option.kind = Kind.RANGE
	option.min_value = low
	option.max_value = high
	option.step = by
	option.default_number = value
	return option

## The value the option has until the player sets it: a bool, a choice's
## name or a float.
func get_default() -> Variant:
	match kind:
		Kind.SWITCH:
			return default_on
		Kind.CHOICE:
			return choices[default_choice] if default_choice >= 0 and default_choice < choices.size() else ""
	return accept(default_number, min_value)

## `value` as the option holds one (a range's number held to its range and
## steps), or `fallback` when it is none: a value of the settings file or of a
## caller is never trusted.
func accept(value: Variant, fallback: Variant) -> Variant:
	match kind:
		Kind.SWITCH:
			return value if typeof(value) == TYPE_BOOL else fallback
		Kind.CHOICE:
			return value if value is String and choices.has(value) else fallback
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var number := clampf(float(value), min_value, max_value)
	return clampf(snappedf(number - min_value, step) + min_value, min_value, max_value) if step > 0.0 else number

## What is wrong with the option as declared.
func find_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	var label := "option '%s'" % id
	if id == &"":
		problems.append("an option has no id")
	elif display_name.is_empty():
		problems.append("%s has no name to show" % label)
	match kind:
		Kind.CHOICE:
			if choices.size() < 2:
				problems.append("%s offers fewer than two choices" % label)
			elif default_choice < 0 or default_choice >= choices.size():
				problems.append("%s starts on a choice it does not offer" % label)
			for name: String in choices:
				if name.is_empty() or choices.count(name) > 1:
					problems.append("%s has an empty or repeated choice" % label)
					break
		Kind.RANGE:
			if not max_value > min_value:
				problems.append("%s has an empty range" % label)
			elif step < 0.0:
				problems.append("%s has a negative step" % label)
			elif default_number < min_value or default_number > max_value:
				problems.append("%s starts outside its range" % label)
	return problems

static func _named(option_id: StringName, label: String) -> GameOption:
	var option := GameOption.new()
	option.id = option_id
	option.display_name = label
	return option
