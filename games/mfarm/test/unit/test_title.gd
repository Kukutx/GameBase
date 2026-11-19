extends GutTest

## MFarm's title screen, the old game's paper menu: its three tabs where the
## old ones stood, the sheet each brings to the top, the slot cards with the
## old words, and the 退出 tab that now quits.

const TitleScene := preload("res://game/ui/title.tscn")
const MenuFit := preload("res://tiamat/core/test/menu_fit.gd")
const TEST_SAVES := "user://test_mfarm_title"

var _save_directory := ""
var _active_slot := 1
var _locale := ""

func before_each() -> void:
	_save_directory = SaveManager.save_directory
	_active_slot = SaveManager.active_slot
	_locale = TranslationServer.get_locale()
	SaveManager.save_directory = TEST_SAVES
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVES))
	SaveManager.select_slot(1)

func after_each() -> void:
	for slot: int in range(1, GameSaveManager.get_slot_count() + 1):
		SaveManager.delete_slot(slot)
	SaveManager.save_directory = _save_directory
	SaveManager.select_slot(_active_slot)
	TranslationServer.set_locale(_locale)

func _title() -> Node:
	var title := TitleScene.instantiate()
	add_child_autofree(title)
	return title

func test_the_title_sheet_is_on_top_with_the_old_tabs_down_the_right_edge() -> void:
	var title := _title()
	var tabs: Dictionary = title.get("tabs")
	assert_eq(title.get("shown"), 2, "the title sheet")
	assert_eq((title.get("paper") as Control).get_child(-1), (title.get("sheets") as Dictionary)[2], "drawn on top")
	assert_eq((tabs[1] as Button).text, "Play")
	assert_eq((tabs[0] as Button).text, "Help")
	assert_eq((tabs[2] as Button).text, "Quit")
	assert_eq((tabs[1] as Button).position, Vector2(218, 14), "开始 stood 60 pixels above the middle")
	assert_eq((tabs[0] as Button).position, Vector2(218, 74), "说明 at the middle")
	assert_eq((tabs[2] as Button).position, Vector2(218, 134), "退出 60 below it")
	for tab: Button in tabs.values():
		assert_eq(tab.size, Vector2(38, 14), "the old tab's size")
	assert_eq(((title.get("cards") as Array)[0] as Button).size, Vector2(148, 27), "the old card's size")
	assert_eq((tabs[2] as Button).visible, GameTitleBase.can_quit(), "a web page has no 退出")
	assert_eq(get_viewport().gui_get_focus_owner(), tabs[1], "the keys and a gamepad start on 开始")
	assert_eq((title.get("title_label") as Label).text, "MFarm")
	assert_string_contains((title.get("version_label") as Label).text, String(ProjectSettings.get_setting("application/config/version")))

func test_a_tab_brings_its_sheet_to_the_top_and_esc_goes_back() -> void:
	var title := _title()
	var tabs: Dictionary = title.get("tabs")
	var contents: Dictionary = title.get("contents")
	(tabs[1] as Button).pressed.emit()
	assert_eq(title.get("shown"), 1)
	assert_true((contents[1] as Control).visible)
	assert_false((contents[2] as Control).visible, "a sheet underneath shows nothing to press")
	assert_eq(get_viewport().gui_get_focus_owner(), (title.get("cards") as Array)[0], "the first card")
	(tabs[0] as Button).pressed.emit()
	assert_eq(title.get("shown"), 0)
	assert_string_contains((title.get("keys_label") as Label).text, "WASD")
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	title.call("_unhandled_input", escape)
	assert_eq(title.get("shown"), 2, "Esc goes back to the title")

func test_an_empty_card_says_the_world_has_not_begun_as_the_old_one_did() -> void:
	TranslationServer.set_locale("zh_CN")
	var title := _title()
	var lines: Array = title.get("card_lines")
	assert_eq(lines.size(), GameSaveManager.get_slot_count(), "a card for each slot")
	assert_eq((lines[0] as Label).text, "这个世界还没有开始\n梦还没开始")
	assert_false(((title.get("delete_buttons") as Array)[0] as Button).visible, "nothing to delete")

func test_a_card_shows_when_and_where_its_game_is_and_what_cannot_be_opened() -> void:
	var title := _title()
	var summary := {"exists": true, "day": 32, "minute_of_day": 7 * 60 + 5, "location_name": "Field", "autosave": false}
	assert_eq(String(title.call("card_text", summary)), "2023.02.02 07:05\nField")
	summary["autosave"] = true
	assert_eq(String(title.call("card_text", summary)), "2023.02.02 07:05\nAutosave · Field")
	TranslationServer.set_locale("zh_CN")
	assert_eq(String(title.call("card_text", summary)), "2023年02月02日 07:05\n自动存档 · 农场")
	assert_eq(String(title.call("card_text", {"exists": false, "unreadable": true})), "这个存档打不开\n点一下重新开始")

func test_a_card_of_a_save_this_version_cannot_open_asks_before_a_new_game_and_can_be_deleted() -> void:
	SaveManager.select_slot(3)
	var unreadable := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	unreadable.store_string("a save of another version")
	unreadable.close()
	SaveManager.select_slot(1)
	var title := _title()
	var delete := (title.get("delete_buttons") as Array)[2] as Button
	assert_true(delete.visible, "it can be deleted")
	((title.get("cards") as Array)[2] as Button).pressed.emit()
	var confirm := title.get("confirm_new_game") as ConfirmationDialog
	assert_true(confirm.visible, "a new game asks before replacing it")
	confirm.hide()
	delete.pressed.emit()
	(title.get("confirm_delete") as ConfirmationDialog).get_ok_button().pressed.emit()
	assert_false(SaveManager.has_files(3))
	assert_false(delete.visible)
	assert_eq((title.get("status_label") as Label).text, "Deleted Slot 3")

func test_the_menu_holds_while_a_game_opens_and_fits_the_view() -> void:
	var title := _title()
	title.call("_set_buttons_disabled", true)
	for button: Button in (title.get("cards") as Array) + (title.get("tabs") as Dictionary).values() + [title.get("settings_button")]:
		assert_true(button.disabled, button.name)
	title.call("_set_buttons_disabled", false)
	await get_tree().process_frame
	assert_eq(MenuFit.find_overflow(title, get_viewport().get_visible_rect()), PackedStringArray())
