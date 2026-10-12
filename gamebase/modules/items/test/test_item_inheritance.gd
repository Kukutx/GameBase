extends GutTest

## Items carried over to a new playthrough or a sequel (`ItemInheritance`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _inventory: Dictionary
var _registry: ContentRegistry

func before_each() -> void:
	_inventory = InventoryState.to_save_data()
	_registry = ContentFixture.use(self, [
		_item(&"fixture_sword", ["weapon"]),
		_item(&"fixture_bow", ["weapon", "ranged"]),
		_item(&"fixture_bread", ["food"]),
	])
	InventoryState.clear()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory)

func test_it_carries_the_items_with_its_tags() -> void:
	var rule := ItemInheritance.new()
	rule.tags = PackedStringArray(["weapon"])
	InventoryState.add_item_by_id(&"fixture_sword", 1)
	InventoryState.add_item_by_id(&"fixture_bow", 2)
	InventoryState.add_item_by_id(&"fixture_bread", 5)
	var carried: Variant = rule.capture()
	assert_eq(carried, {"fixture_sword": 1, "fixture_bow": 2})
	InventoryState.clear()
	rule.apply(carried)
	assert_eq(InventoryState.get_quantity(&"fixture_sword"), 1)
	assert_eq(InventoryState.get_quantity(&"fixture_bow"), 2)
	assert_eq(InventoryState.get_quantity(&"fixture_bread"), 0)

func test_without_tags_it_carries_every_item_it_knows() -> void:
	var rule := ItemInheritance.new()
	rule.apply({"fixture_bread": 3.0, "fixture_gone": 4, "fixture_sword": -1, "fixture_bow": "two"})
	assert_eq(InventoryState.get_quantity(&"fixture_bread"), 3, "a count JSON gave back")
	assert_eq(InventoryState.get_used_slots(), 1, "nothing unknown or miscounted")
	rule.apply([1, 2])
	assert_eq(InventoryState.get_used_slots(), 1)

func test_a_tag_no_item_has_is_a_problem() -> void:
	var rule := ItemInheritance.new()
	rule.tags = PackedStringArray(["weapon", "wepon"])
	assert_eq(rule.find_problems(_registry), PackedStringArray(["carries items tagged 'wepon', which no item has"]))

func _item(id: StringName, tags: Array[String]) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.tags = PackedStringArray(tags)
	return item
