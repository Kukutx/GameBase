class_name GameModulesService
extends Node

## Installs every `GameModule` the game links, then has `ContentDB` index and
## check the game's content and `GameRules` check the conditions and actions it
## names, now that every module registered its kinds and rule keys. A release
## build only indexes: its content passed the checks before it shipped.
##
## A game links only the modules its `game.json` lists (`tools/link.js`), so the
## global classes extending `GameModule` are exactly the game's modules and the
## game's own. They install in class-name order; what they register carries
## its own order. The autoload comes right after `ContentDB`, before every
## module service, so content is indexed before any service reads it.

var _modules: Array[GameModule] = []

func _ready() -> void:
	for script: Script in find_module_scripts():
		var module := script.new() as GameModule
		module.install()
		_modules.append(module)
	# The checks open every location's scene, which only slows a release
	# build's start; its content passed them before the export.
	if not OS.is_debug_build():
		ContentDB.checked_before_export = true
		for problem: String in ContentDB.index():
			push_error("ContentDB: " + problem)
		return
	ContentDB.rebuild()
	for problem: String in GameRules.validate_content(ContentDB):
		push_error("GameRules: " + problem)

## What every installed module tells about the game now
## (`GameModule.get_facts()`), its sections merged in install order.
func get_facts() -> Dictionary:
	var facts := {}
	for module: GameModule in _modules:
		facts.merge(module.get_facts(), true)
	return facts

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
