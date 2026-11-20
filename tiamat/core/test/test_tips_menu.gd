extends GutTest

## The tips the player has seen, read again from the pause menu (`TipsMenu`):
## offered once a hint has shown, each naming its controls as the device in
## use performs them, fitting each view the game is laid out in, and closed
## by `ui_cancel` back to the pause menu.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const MenuFit := preload("res://tiamat/core/test/menu_fit.gd")
const TEST_PATH := "user://test_tips_menu/profile.json"

var _saved_path: String
var _saved: Dictionary

func before_each() -> void:
	_saved_path = GameProfile.profile_path
	_saved = GameProfile.to_save_data()
	GameProfile.profile_path = TEST_PATH
	GameProfile.load_save_data({})
	ContentFixture.use(self, [
		_hint(&"fixture_b_talk", "Talk to anyone with {interact}."),
		_hint(&"fixture_a_walk", "Walk with {move}."),
		_hint(&"fixture_c_unseen", "A tip not shown yet."),
	])

func after_each() -> void:
	InputPrompts.call("_set_using_touch", false)
	ContentRegistry.active = ContentDB
	GameProfile.load_save_data(_saved)
	GameProfile.profile_path = _saved_path

func test_the_pause_menu_offers_the_tips_once_one_has_shown() -> void:
	var pause := _pause()
	pause.open()
	assert_false(pause.tips_button.visible, "no tip has shown yet")
	pause.close()
	GameProfile.set_flag(HintData.get_shown_flag(&"fixture_b_talk"), true)
	pause.open()
	assert_true(pause.tips_button.visible)
	pause.close()

func test_the_tips_read_as_the_device_in_use_names_the_controls() -> void:
	for id: StringName in [&"fixture_a_walk", &"fixture_b_talk"]:
		GameProfile.set_flag(HintData.get_shown_flag(id), true)
	var pause := _pause()
	pause.open()
	pause.tips_button.pressed.emit()
	var tips := pause.tips_menu
	assert_true(tips.visible)
	assert_true(pause.resume_button.disabled, "the pause menu waits under it")
	var walk := HintData.find(&"fixture_a_walk").get_message()
	var talk := HintData.find(&"fixture_b_talk").get_message()
	assert_eq(tips.get_texts(), PackedStringArray([walk, talk]), "the tips seen, and only those")
	InputPrompts.call("_set_using_touch", true)
	assert_ne(HintData.find(&"fixture_b_talk").get_message(), talk, "touch names interact otherwise")
	assert_eq(tips.get_texts()[1], HintData.find(&"fixture_b_talk").get_message(), "a tip names its controls anew")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	tips._unhandled_input(cancel)
	assert_false(tips.visible, "cancel closes the tips")
	assert_true(pause.visible, "and leaves the pause menu open")
	assert_false(pause.resume_button.disabled)
	pause.close()

func test_the_tips_fit_each_view() -> void:
	for id: StringName in [&"fixture_a_walk", &"fixture_b_talk", &"fixture_c_unseen"]:
		GameProfile.set_flag(HintData.get_shown_flag(id), true)
	var pause := _pause()
	pause.open()
	await get_tree().process_frame
	assert_eq(await MenuFit.find_overflow_in_views(pause), PackedStringArray(), "the pause menu with every button")
	pause.tips_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(await MenuFit.find_overflow_in_views(pause.tips_menu), PackedStringArray(), "the tips")
	pause.close()

func _pause() -> PauseMenu:
	var menu := (load("res://tiamat/core/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	add_child_autofree(menu)
	return menu

func _hint(id: StringName, text: String) -> HintData:
	var hint := HintData.new()
	hint.id = id
	hint.text = text
	return hint
