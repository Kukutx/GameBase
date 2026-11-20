class_name GameOptions
extends RefCounted

## The options of the running game (`GameOption`): the game's own
## (`GameDefinition.options`), then those its modules declare
## (`GameModule.get_options()`), and the player's value of each.
## `GameSettings` keeps them (`GameSettings.options`) and writes them to the
## settings file, where a value of an option the game no longer declares stays
## as it was, so a module the game drops and takes back finds the player's
## choice again.

var _declared: Array[GameOption] = []
# id -> the player's value, as the option holds one (`GameOption.accept()`).
var _values: Dictionary[StringName, Variant] = {}
# The settings file's values of options the game does not declare.
var _kept: Dictionary = {}

func _init(declared: Array[GameOption] = []) -> void:
	_declared = declared
	reset()

## The running game's `GameDefinition.options`; an entry that is not a
## `GameOption` becomes null, which `find_problems()` reports.
static func of_game() -> Array[GameOption]:
	var result: Array[GameOption] = []
	for entry: Resource in GameDefinition.current().options:
		result.append(entry as GameOption)
	return result

## The options the game's modules declare, in the order they install.
static func of_modules() -> Array[GameOption]:
	var result: Array[GameOption] = []
	for script: Script in GameModulesService.find_module_scripts():
		result.append_array((script.new() as GameModule).get_options())
	return result

## The running game's options, in settings order (`resolve()`).
static func of_running_game() -> GameOptions:
	return GameOptions.new(resolve(of_game(), of_modules()))

## The game's options, then its modules'; the first option of an id replaces
## the later ones, so a game replaces a module's option (its default, its
## choices) by listing its id.
static func resolve(game_options: Array[GameOption], module_options: Array[GameOption]) -> Array[GameOption]:
	var result: Array[GameOption] = []
	var listed: Dictionary[StringName, bool] = {}
	for option: GameOption in game_options + module_options:
		if option != null and option.id != &"" and not listed.has(option.id):
			result.append(option)
			listed[option.id] = true
	return result

## What is wrong with a game's options and its modules'.
static func find_problems(game_options: Array[GameOption], module_options: Array[GameOption]) -> PackedStringArray:
	var problems := PackedStringArray()
	if game_options.has(null):
		problems.append("GameDefinition.options has an entry that is not a GameOption")
	if module_options.has(null):
		problems.append("a module declares an option that is not a GameOption")
	for id: StringName in _find_repeated(game_options):
		problems.append("option '%s' is listed twice" % id)
	for id: StringName in _find_repeated(module_options):
		problems.append("two modules declare option '%s'" % id)
	for option: GameOption in game_options + module_options:
		if option != null:
			problems.append_array(option.find_problems())
	return problems

static func _find_repeated(options: Array[GameOption]) -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	var repeated: Array[StringName] = []
	for option: GameOption in options:
		if option == null or option.id == &"":
			continue
		if seen.has(option.id) and not repeated.has(option.id):
			repeated.append(option.id)
		seen[option.id] = true
	return repeated

## The options, in settings order.
func get_declared() -> Array[GameOption]:
	return _declared

## The option `id`, or null when the game declares none.
func find(id: StringName) -> GameOption:
	for option: GameOption in _declared:
		if option.id == id:
			return option
	return null

## The player's value of the option `id`: a bool, a choice's name or a float;
## null, and an error, for an option the game does not declare.
func get_value(id: StringName) -> Variant:
	if not _values.has(id):
		push_error("GameOptions: no option '%s' is declared" % id)
		return null
	return _values[id]

## Sets the option `id` to `value`, as the option holds one; whether its value
## changed.
func set_value(id: StringName, value: Variant) -> bool:
	var option := find(id)
	if option == null:
		push_error("GameOptions: no option '%s' is declared" % id)
		return false
	var accepted: Variant = option.accept(value, _values[id])
	if accepted == _values[id]:
		return false
	_values[id] = accepted
	return true

## Gives every option its default back.
func reset() -> void:
	_values.clear()
	for option: GameOption in _declared:
		_values[option.id] = option.get_default()

## The values as the settings file holds them, those of options the game no
## longer declares too.
func to_data() -> Dictionary:
	var data := _kept.duplicate()
	for id: StringName in _values:
		data[String(id)] = _values[id]
	return data

## Reads the values of the settings file's `data`; a value an option does not
## hold keeps the option's current one.
func read_data(data: Variant) -> void:
	_kept.clear()
	if not data is Dictionary:
		return
	for key: Variant in data:
		var option := find(StringName(str(key)))
		if option == null:
			_kept[str(key)] = data[key]
		else:
			_values[option.id] = option.accept(data[key], _values[option.id])
