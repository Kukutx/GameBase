class_name GameModulesService
extends Node

## Installs every `GameModule` the game links, then checks the conditions and
## actions content names now that every module registered its rule keys.
##
## A game links only the modules its `game.json` lists (`tools/link.js`), so the
## global classes extending `GameModule` are exactly the game's modules. They
## install in class-name order; what they register carries its own order.

var _modules: Array[GameModule] = []

func _ready() -> void:
	for script: Script in find_module_scripts():
		var module := script.new() as GameModule
		module.install()
		_modules.append(module)
	# Content is indexed before the modules register their rule keys, so the
	# conditions and actions it names are checked here, once every key exists.
	for problem: String in GameRules.validate_content(ContentDB):
		push_error("GameRules: " + problem)

## The class names of the installed modules.
func get_installed() -> PackedStringArray:
	var names := PackedStringArray()
	for module: GameModule in _modules:
		names.append(module.get_script().get_global_name())
	return names

## Every global class that extends `GameModule`, by class name.
static func find_module_scripts() -> Array[Script]:
	var bases: Dictionary = {}
	var paths: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		bases[entry["class"]] = entry["base"]
		paths[entry["class"]] = entry["path"]
	var names: Array[StringName] = []
	for name: StringName in bases:
		var base: StringName = bases[name]
		while bases.has(base) and base != &"GameModule":
			base = bases[base]
		if base == &"GameModule" and name != &"GameModule":
			names.append(name)
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var scripts: Array[Script] = []
	for name: StringName in names:
		scripts.append(load(paths[name]) as Script)
	return scripts
