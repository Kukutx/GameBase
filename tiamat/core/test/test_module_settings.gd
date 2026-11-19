extends GutTest

## What a game sets for its modules (`ModuleSettings`,
## `GameDefinition.module_settings`): the listed settings of a kind, that
## kind's defaults otherwise, and the problems of the list.

## Settings of a fixture module.
class FixtureSettings extends ModuleSettings:
	@export var speed := 1

	func find_problems(_registry: ContentRegistry) -> PackedStringArray:
		return PackedStringArray(["speed %d is too slow" % speed]) if speed < 1 else PackedStringArray()

## Settings of another fixture module, whose defaults are wrong.
class OtherSettings extends ModuleSettings:
	@export var value := 0

	func find_problems(_registry: ContentRegistry) -> PackedStringArray:
		return PackedStringArray(["value %d is too low" % value]) if value < 1 else PackedStringArray()

func test_a_game_gets_the_settings_it_lists_or_the_defaults() -> void:
	var definition := GameDefinition.new()
	var listed := FixtureSettings.new()
	listed.speed = 3
	definition.module_settings = [listed]
	assert_same(definition.get_settings(FixtureSettings), listed)
	var defaults := definition.get_settings(OtherSettings)
	assert_true(defaults is OtherSettings, "the kind's defaults")
	assert_same(definition.get_settings(OtherSettings), defaults, "the same defaults each time")
	assert_eq(definition.find_settings_problems(ContentDB), PackedStringArray(), "only what the game lists")
	assert_eq(definition.find_settings_problems(ContentDB, [OtherSettings]), PackedStringArray(["ModuleSettings: value 0 is too low"]),
		"and the defaults of a kind its modules use")

func test_the_list_s_problems_are_named() -> void:
	var definition := GameDefinition.new()
	var slow := FixtureSettings.new()
	slow.speed = 0
	definition.module_settings = [slow, FixtureSettings.new(), VitalData.new(), null]
	assert_eq(definition.find_settings_problems(ContentDB, [FixtureSettings]), PackedStringArray([
		"the game lists ModuleSettings twice",
		"the game lists module settings that are no ModuleSettings",
		"the game lists module settings that are no ModuleSettings",
		"ModuleSettings: speed 0 is too slow",
	]), "the listed settings, checked once")
