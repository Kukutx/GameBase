extends GutTest

## The condition and action keys the items module registers (`ItemsRules`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _inventory: Dictionary
var _max_slots: int

func before_each() -> void:
	_inventory = InventoryState.to_save_data()
	_max_slots = InventoryState.max_slots
	var item := ItemData.new()
	item.id = &"fixture_berry"
	item.display_name = "Fixture Berry"
	ContentFixture.use(self, [item])

func after_each() -> void:
	ContentRegistry.active = ContentDB
	InventoryState.max_slots = _max_slots
	InventoryState.load_save_data(_inventory)

func test_item_keys_are_registered_and_checked_against_content() -> void:
	assert_true(GameRules.has_condition(&"HAS_ITEM"))
	for key: String in ["ADD_ITEM", "REMOVE_ITEM"]:
		assert_true(GameRules.has_action(StringName(key)), key)
	assert_eq(GameRules.validate_query("HAS_ITEM fixture_berry 2"), PackedStringArray())
	assert_eq(GameRules.validate_actions(PackedStringArray(["ADD_ITEM fixture_berry 2", "REMOVE_ITEM fixture_berry"])), PackedStringArray())
	var problems := "\n".join(GameRules.validate_query("HAS_ITEM no_such_item, HAS_ITEM fixture_berry lots"))
	assert_string_contains(problems, "unknown item 'no_such_item'")
	assert_string_contains(problems, "'lots' is not a count")
	var counts := "\n".join(GameRules.validate_actions(PackedStringArray(["ADD_ITEM fixture_berry -1", "REMOVE_ITEM fixture_berry 0"])))
	assert_string_contains(counts, "'-1' is not a count (a whole number of at least 1)")
	assert_string_contains(counts, "'0' is not a count")
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["ADD_ITEM no_such_item"]))), "unknown item 'no_such_item'")

func test_adding_items_that_do_not_all_fit_adds_none() -> void:
	InventoryState.clear()
	InventoryState.max_slots = 1
	var berry := ItemData.find(&"fixture_berry")
	assert_true(GameRules.run_actions(PackedStringArray(["ADD_ITEM fixture_berry %d" % (berry.max_stack - 1)])))
	assert_false(GameRules.run_actions(PackedStringArray(["ADD_ITEM fixture_berry 2"])), "only one more fits")
	assert_eq(InventoryState.get_quantity(&"fixture_berry"), berry.max_stack - 1, "and none was added")
