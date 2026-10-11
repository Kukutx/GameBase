extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func before_each() -> void:
	ContentFixture.use(self, [_item(&"fixture_pick"), _item(&"fixture_hoe")])

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB

func test_hotbar_round_trip() -> void:
	var hotbar := HotbarService.new()
	add_child_autofree(hotbar)
	assert_true(hotbar.set_slot_item(2, &"fixture_pick"))
	hotbar.select_slot(2)
	var restored := HotbarService.new()
	add_child_autofree(restored)
	restored.load_save_data(hotbar.to_save_data())
	assert_eq(restored.selected_slot, 2)
	assert_eq(restored.get_selected_item_id(), &"fixture_pick")
	assert_eq(restored.get_selected_item(), ItemData.find(&"fixture_pick"))

func test_removed_legacy_hotbar_item_is_cleared_without_touching_inventory_payload() -> void:
	var hotbar := HotbarService.new()
	add_child_autofree(hotbar)
	hotbar.load_save_data({
		"selected_slot": 0,
		"slots": ["removed_item", "fixture_hoe", "", "", "", "", "", "", ""],
	})
	assert_eq(hotbar.slots[0], &"")
	assert_eq(hotbar.slots[1], &"fixture_hoe")
	assert_eq(hotbar.get_selected_item_id(), &"")
	assert_null(hotbar.get_selected_item())

static func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
