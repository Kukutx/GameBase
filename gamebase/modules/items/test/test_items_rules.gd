extends GutTest

## The condition and action keys the items module registers (`ItemsRules`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func before_each() -> void:
	var item := ItemData.new()
	item.id = &"fixture_berry"
	item.display_name = "Fixture Berry"
	ContentFixture.use(self, [item])

func test_item_keys_are_registered_and_checked_against_content() -> void:
	assert_true(GameRules.has_condition(&"HAS_ITEM"))
	for key: String in ["ADD_ITEM", "REMOVE_ITEM"]:
		assert_true(GameRules.has_action(StringName(key)), key)
	assert_eq(GameRules.validate_query("HAS_ITEM fixture_berry 2"), PackedStringArray())
	assert_eq(GameRules.validate_actions(PackedStringArray(["ADD_ITEM fixture_berry 2", "REMOVE_ITEM fixture_berry"])), PackedStringArray())
	var problems := "\n".join(GameRules.validate_query("HAS_ITEM no_such_item, HAS_ITEM fixture_berry lots"))
	assert_string_contains(problems, "unknown item 'no_such_item'")
	assert_string_contains(problems, "'lots' is not an integer")
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["ADD_ITEM no_such_item"]))), "unknown item 'no_such_item'")
