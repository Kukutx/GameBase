extends GutTest

## The title screen every game opens on (`core/ui/title_screen.tscn`): its
## save slot controls and the summary of the selected slot, dated by the
## game's calendar.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

func test_the_title_screen_shows_the_slot_summary_by_the_calendar() -> void:
	var title: Node = autofree((load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate())
	for path: String in ["Center/Menu/SlotRow/SaveSlot", "Center/Menu/SlotInfo", "Center/Menu/SlotRow/DeleteSave", "ConfirmDelete"]:
		assert_not_null(title.get_node_or_null(path), path)
	var summary := {"day": 68, "minute_of_day": 600, "recoverable": true, "recovery_source": "backup"}
	ContentFixture.use_calendar(self, GameCalendar.new())
	assert_eq(String(title.call("_format_slot_summary", summary)), "Autumn 12 · 10:00 · backup available\nPlayed 0:00")
	var one_season := GameCalendar.new()
	one_season.season_names = PackedStringArray(["Run"])
	ContentFixture.use_calendar(self, one_season)
	summary["recoverable"] = false
	assert_eq(String(title.call("_format_slot_summary", summary)), "Day 68 · 10:00\nPlayed 0:00")

func test_its_buttons_stand_in_rows_as_full_as_each_other() -> void:
	var expected := {1: 1, 2: 2, 3: 3, 4: 2, 5: 3, 6: 3, 7: 3, 8: 3, 9: 3, 10: 3}
	for count: int in expected:
		assert_eq(EvenRows.columns_for(count, 3), int(expected[count]), "%d buttons" % count)
	assert_eq(EvenRows.columns_for(0, 3), 1)
	var title := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate() as GameTitleScreen
	add_child_autofree(title)
	var actions := title.get_node("Center/Menu/Actions") as GridContainer
	title.achievements_button.visible = true
	title.quit_button.visible = true
	assert_eq(actions.columns, 2, "a new game, the settings, the achievements and quitting in two rows of two")
	title.achievements_button.visible = false
	assert_eq(actions.columns, 3, "three in one row")
	title.quit_button.visible = false
	assert_eq(actions.columns, 2, "two in one row")

func test_a_slot_shows_where_the_player_stands_how_long_they_played_and_what_the_game_adds() -> void:
	var title: Node = autofree((load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate())
	ContentFixture.use_calendar(self, GameCalendar.new())
	var summary := {
		"day": 3, "minute_of_day": 375, "recoverable": false,
		"location_name": "Meadow", "play_seconds": 2 * 3600 + 7 * 60 + 59,
		"details": PackedStringArray(["50g", "Deepest 4", "Run 2"]),
	}
	assert_eq(String(title.call("_format_slot_summary", summary)), "Spring 3 · 06:15\nMeadow · Played 2:07\n50g · Deepest 4 · Run 2")
	summary["autosave"] = true
	assert_eq(String(title.call("_format_slot_summary", summary)), "Autosave · Spring 3 · 06:15\nMeadow · Played 2:07\n50g · Deepest 4 · Run 2", "a slot that continues from its autosave says so")

func test_a_new_game_that_fails_after_it_started_gives_the_menu_back() -> void:
	var title := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(title)
	title.call("_set_buttons_disabled", true)
	# The start location's scene failed to load after the travel started.
	GameSession.new_game_failed.emit()
	assert_false(title.new_game_button.disabled)
	assert_eq((title.get("status_label") as Label).text, "Could not open the starting location")

func test_a_continue_that_fails_says_why_and_gives_the_menu_back() -> void:
	var title := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(title)
	title.call("_set_buttons_disabled", true)
	SaveManager.load_completed.emit(false, "Slot 1 has no save to load")
	assert_false(title.new_game_button.disabled)
	assert_eq((title.get("status_label") as Label).text, "Slot 1 has no save to load")

func test_a_slot_this_version_cannot_open_is_shown_and_replaced_only_after_asking() -> void:
	var save_directory := SaveManager.save_directory
	var active_slot := SaveManager.active_slot
	SaveManager.save_directory = "user://test_title_screen"
	SaveManager.select_slot(1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveManager.save_directory))
	var unreadable := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	unreadable.store_string("a save of another version")
	unreadable.close()
	var title := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(title)
	assert_eq(title.slot_info.text, "Holds a save this version cannot open")
	assert_true(title.continue_button.disabled)
	assert_false(title.delete_button.disabled, "it can be deleted")
	title.call("_new_game")
	var confirm := title.get_node("ConfirmNewGame") as ConfirmationDialog
	assert_true(confirm.visible, "a new game asks before replacing it")
	assert_string_contains(confirm.dialog_text, "cannot open")
	assert_true(FileAccess.file_exists(SaveManager.save_path))
	confirm.hide()
	SaveManager.delete_slot(1)
	SaveManager.save_directory = save_directory
	SaveManager.select_slot(active_slot)

func test_the_title_offers_as_many_slots_as_the_game_sets() -> void:
	var definition := GameDefinition.new()
	definition.save_slots = 5
	var title: Node = ContentFixture.with_definition(definition, func() -> Node:
		var screen := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate()
		add_child_autofree(screen)
		return screen
	)
	assert_eq((title.get("slot_select") as OptionButton).item_count, 5)

func test_a_title_of_its_own_gets_the_questions_and_settings_it_lacks() -> void:
	var title := GameTitleBase.new()
	add_child_autofree(title)
	assert_not_null(title.settings_menu, "the core's settings menu")
	assert_eq(title.settings_menu.get_parent(), title)
	assert_eq(title.confirm_new_game.get_ok_button().text, "Start New Game")
	assert_eq(title.confirm_delete.get_ok_button().text, "Delete")
	assert_eq(title.confirm_delete.get_cancel_button().text, "Cancel")
	assert_eq(GameTitleBase.can_quit(), not OS.has_feature("web"))

func test_opening_a_slot_that_holds_an_unreadable_save_asks_and_deleting_one_asks() -> void:
	var save_directory := SaveManager.save_directory
	var active_slot := SaveManager.active_slot
	SaveManager.save_directory = "user://test_title_base"
	SaveManager.select_slot(2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveManager.save_directory))
	var unreadable := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	unreadable.store_string("a save of another version")
	unreadable.close()
	SaveManager.select_slot(1)
	var title := GameTitleBase.new()
	add_child_autofree(title)
	title.open_slot(2)
	assert_eq(SaveManager.active_slot, 2, "the slot is chosen")
	assert_true(title.confirm_new_game.visible, "a new game asks before replacing what the slot holds")
	assert_string_contains(title.confirm_new_game.dialog_text, "Save Slot 2")
	title.confirm_new_game.hide()
	title.delete_slot(2)
	assert_true(title.confirm_delete.visible, "deleting asks")
	title.confirm_delete.get_ok_button().pressed.emit()
	assert_false(SaveManager.has_files(2), "and deletes once the player agrees")
	SaveManager.save_directory = save_directory
	SaveManager.select_slot(active_slot)

func test_a_browser_that_keeps_no_saves_is_named_as_the_title_opens() -> void:
	var persist := GameSaveManager.saves_persist
	var title := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(title)
	await wait_process_frames(1)
	assert_eq(title.status_label.text, "", "saves that last need no word")
	GameSaveManager.saves_persist = false
	var forgetful := (load("res://tiamat/core/ui/title_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(forgetful)
	await wait_process_frames(1)
	GameSaveManager.saves_persist = persist
	assert_eq(forgetful.status_label.text, GameTitleBase.SAVES_LOST)

