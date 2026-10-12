extends GutTest

## The title screen every game opens on (`core/ui/title_screen.tscn`): its
## save slot controls and the summary of the selected slot, dated by the
## game's calendar.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_the_title_screen_shows_the_slot_summary_by_the_calendar() -> void:
	var title: Node = autofree((load("res://gamebase/core/ui/title_screen.tscn") as PackedScene).instantiate())
	for path: String in ["Center/Menu/SaveSlot", "Center/Menu/SlotInfo", "Center/Menu/Actions/DeleteSave", "ConfirmDelete"]:
		assert_not_null(title.get_node_or_null(path), path)
	var summary := {"day": 68, "minute_of_day": 600, "recoverable": true, "recovery_source": "backup"}
	ContentFixture.use_calendar(self, GameCalendar.new())
	assert_eq(String(title.call("_format_slot_summary", summary)), "Autumn 12 · 10:00 · backup available\nPlayed 0:00")
	var one_season := GameCalendar.new()
	one_season.season_names = PackedStringArray(["Run"])
	ContentFixture.use_calendar(self, one_season)
	summary["recoverable"] = false
	assert_eq(String(title.call("_format_slot_summary", summary)), "Day 68 · 10:00\nPlayed 0:00")

func test_a_slot_shows_where_the_player_stands_how_long_they_played_and_what_the_game_adds() -> void:
	var title: Node = autofree((load("res://gamebase/core/ui/title_screen.tscn") as PackedScene).instantiate())
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
	var title := (load("res://gamebase/core/ui/title_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(title)
	title.call("_set_buttons_disabled", true)
	# The start location's scene failed to load after the travel started.
	GameSession.new_game_failed.emit()
	assert_false(title.new_game_button.disabled)
	assert_eq((title.get("status_label") as Label).text, "Could not open the starting location")

func test_a_continue_that_fails_says_why_and_gives_the_menu_back() -> void:
	var title := (load("res://gamebase/core/ui/title_screen.tscn") as PackedScene).instantiate()
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
	var title := (load("res://gamebase/core/ui/title_screen.tscn") as PackedScene).instantiate()
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
		var screen := (load("res://gamebase/core/ui/title_screen.tscn") as PackedScene).instantiate()
		add_child_autofree(screen)
		return screen
	)
	assert_eq((title.get("slot_select") as OptionButton).item_count, 5)
