extends GutTest

## What the modules tell about the game (`GameModule.get_facts()`), which
## `GameModules.get_facts()` gathers for whatever describes the game.

class FixtureBag extends GameModule:
	func get_facts() -> Dictionary:
		return {"fixture_bag": ["twig"], "fixture_notes": "first"}

class FixtureNotes extends GameModule:
	func get_facts() -> Dictionary:
		return {"fixture_notes": "second"}

func test_the_modules_facts_are_gathered_in_install_order() -> void:
	var modules := GameModulesService.new()
	modules._modules = [FixtureBag.new(), GameModule.new(), FixtureNotes.new()]
	assert_eq(modules.get_facts(), {"fixture_bag": ["twig"], "fixture_notes": "second"}, "a module with none adds none")
	modules.free()

func test_the_game_s_modules_tell_plain_data() -> void:
	var facts := GameModules.get_facts()
	for section: Variant in facts:
		assert_true(section is String, "section %s is named by text" % [section])
		assert_true(_is_plain(facts[section]), "section %s is plain data: %s" % [section, facts[section]])

# Whether `value` holds only text, numbers, booleans, null, arrays and
# dictionaries keyed by text.
func _is_plain(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			return (value as Array).all(_is_plain)
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			return dictionary.keys().all(func(key: Variant) -> bool: return key is String) and dictionary.values().all(_is_plain)
	return false
