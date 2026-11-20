extends GutTest

## The hotbar's slots (`HotbarService`): saved and loaded, and picked by a
## press on the HUD's line (`HotbarLine`).

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

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

func test_a_press_on_a_slot_of_the_hud_line_picks_it() -> void:
	var saved := Hotbar.to_save_data()
	Hotbar.load_save_data({"selected_slot": 0, "slots": ["fixture_pick", "", "fixture_hoe", "", "", "", "", "", ""]})
	var line := HotbarLine.new()
	add_child_autofree(line)
	line.size = Vector2(400, 20)
	line.refresh()
	assert_eq(line.text, ">1:Fixture Pick x0   3:Fixture Hoe x0")
	assert_eq(line.mouse_filter, Control.MOUSE_FILTER_PASS, "a press beside the slots passes on to the game")
	var font := line.get_theme_font(&"font")
	var font_size := line.get_theme_font_size(&"font_size")
	var first := font.get_string_size(">1:Fixture Pick x0", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap := font.get_string_size(HotbarService.PART_SEPARATOR, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	assert_eq(line.get_slot_at(first / 2.0), 0)
	assert_eq(line.get_slot_at(first + gap * 0.25), 0, "a press just past a part is still the part's")
	assert_eq(line.get_slot_at(first + gap + 4.0), 2)
	assert_eq(line.get_slot_at(390.0), -1, "nothing past the last slot")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(first + gap + 4.0, 8.0)
	line._gui_input(press)
	assert_eq(Hotbar.selected_slot, 2, "a press picks the slot")
	InputLock.lock(&"fixture_menu")
	press.position = Vector2(first / 2.0, 8.0)
	line._gui_input(press)
	InputLock.unlock(&"fixture_menu")
	assert_eq(Hotbar.selected_slot, 2, "not while the player cannot act")
	Hotbar.load_save_data(saved)

static func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
