extends GutTest

## The game's achievements, from the title and the pause menu
## (`AchievementsMenu`): offered in a game that has any, counting those
## unlocked, showing the unlocked first in the order they were and the locked
## dimmed, a hidden one keeping to itself until unlocked; the keys walk
## through them; it fits each view the game is laid out in, and `ui_cancel`
## closes it back to the menu that opened it.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const MenuFit := preload("res://tiamat/core/test/menu_fit.gd")
const TEST_PATH := "user://test_achievements_menu/profile.json"

var _saved_path: String
var _saved: Dictionary

func before_each() -> void:
	_saved_path = GameProfile.profile_path
	_saved = GameProfile.to_save_data()
	GameProfile.profile_path = TEST_PATH
	GameProfile.load_save_data({})
	ContentFixture.use(self, [
		_achievement(&"fixture_a_first_step", "First Step", "Take a step."),
		_achievement(&"fixture_b_far", "Far Away", "Walk a long way."),
		_achievement(&"fixture_c_secret", "Secret", "Find the secret.", true),
		_achievement(&"fixture_d_last", "Last", "Do it last."),
	])

func after_each() -> void:
	ContentRegistry.active = ContentDB
	GameProfile.load_save_data(_saved)
	GameProfile.profile_path = _saved_path

func test_the_unlocked_come_first_in_their_order_and_a_hidden_one_keeps_to_itself() -> void:
	GameProfile.load_save_data({"profile_version": GameProfileService.PROFILE_VERSION, "achievements": {"fixture_d_last": 100, "fixture_b_far": 200}})
	var pause := _pause()
	pause.open()
	assert_true(pause.achievements_button.visible, "a game with achievements offers them")
	pause.achievements_button.pressed.emit()
	var menu := pause.achievements_menu
	assert_true(menu.visible)
	assert_true(pause.resume_button.disabled, "the pause menu waits under it")
	assert_eq(menu.get_summary(), "2 of 4 unlocked")
	assert_eq(menu.get_entries(), [
		PackedStringArray(["Last", "Do it last."]),
		PackedStringArray(["Far Away", "Walk a long way."]),
		PackedStringArray(["First Step", "Take a step."]),
		PackedStringArray([AchievementsMenu.HIDDEN_NAME, AchievementsMenu.HIDDEN_DESCRIPTION]),
	] as Array[PackedStringArray])
	assert_eq([menu.is_entry_locked(0), menu.is_entry_locked(1), menu.is_entry_locked(2), menu.is_entry_locked(3)], [false, false, true, true])
	assert_true(get_viewport().gui_get_focus_owner() is MenuEntry, "the keys start on the first")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	menu._unhandled_input(cancel)
	assert_false(menu.visible, "cancel closes it")
	assert_true(pause.visible, "and leaves the pause menu open")
	assert_false(pause.resume_button.disabled)
	assert_true(pause.achievements_button.has_focus())
	GameProfile.unlock(&"fixture_c_secret")
	pause.achievements_button.pressed.emit()
	assert_eq(menu.get_summary(), "3 of 4 unlocked")
	assert_eq(menu.get_entries()[2], PackedStringArray(["Secret", "Find the secret."]), "unlocked, a hidden one shows itself")
	pause.close()
	assert_false(menu.visible, "closing the pause menu closes it")

func test_a_game_without_achievements_offers_none() -> void:
	ContentFixture.use(self, [])
	var pause := _pause()
	pause.open()
	assert_false(pause.achievements_button.visible)
	pause.close()
	var title := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate() as GameTitleScreen
	add_child_autofree(title)
	assert_false(title.achievements_button.visible)

func test_the_title_opens_them_and_the_keys_walk_through_them() -> void:
	var title := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate() as GameTitleScreen
	add_child_autofree(title)
	assert_true(title.achievements_button.visible)
	title.achievements_button.pressed.emit()
	var menu := title.achievements_menu
	assert_true(menu.visible)
	assert_true(title.new_game_button.disabled, "the title waits under it")
	await get_tree().process_frame
	var first := get_viewport().gui_get_focus_owner()
	assert_true(first is MenuEntry)
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	get_viewport().push_input(down)
	await get_tree().process_frame
	var second := get_viewport().gui_get_focus_owner()
	assert_true(second is MenuEntry and second != first, "down goes to the next")
	menu.close()
	assert_false(title.new_game_button.disabled)
	assert_true(title.achievements_button.has_focus())

func test_the_achievements_fit_each_view() -> void:
	var pause := _pause()
	pause.open()
	pause.achievements_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(await MenuFit.find_overflow_in_views(pause.achievements_menu), PackedStringArray())
	pause.close()

func _pause() -> PauseMenu:
	var menu := (load("res://tiamat/core/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	add_child_autofree(menu)
	return menu

func _achievement(id: StringName, title: String, description: String, hidden := false) -> AchievementData:
	var achievement := AchievementData.new()
	achievement.id = id
	achievement.display_name = title
	achievement.description = description
	achievement.hidden = hidden
	return achievement
