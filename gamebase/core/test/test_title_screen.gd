extends GutTest

## The title screen every game opens on (`core/ui/title_screen.tscn`): its
## save slot controls and the summary of the selected slot, dated by the
## game's calendar.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_the_title_screen_shows_the_slot_summary_by_the_calendar() -> void:
	var title: Node = autofree((load("res://gamebase/core/ui/title_screen.tscn") as PackedScene).instantiate())
	for path: String in ["Center/Menu/SaveSlot", "Center/Menu/SlotInfo", "Center/Menu/DeleteSave", "ConfirmDelete"]:
		assert_not_null(title.get_node_or_null(path), path)
	var summary := {"day": 68, "minute_of_day": 600, "money": 4321, "recoverable": true, "recovery_source": "backup"}
	ContentFixture.use_calendar(self, GameCalendar.new())
	assert_eq(String(title.call("_format_slot_summary", summary)), "Autumn 12 · 10:00 · 4321g · backup available")
	var one_season := GameCalendar.new()
	one_season.season_names = PackedStringArray(["Run"])
	ContentFixture.use_calendar(self, one_season)
	summary["recoverable"] = false
	assert_eq(String(title.call("_format_slot_summary", summary)), "Day 68 · 10:00 · 4321g")

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
	assert_eq((title.get_node("Center/Menu/SlotInfo") as Label).text, "Holds a save this version cannot open")
	assert_true((title.get_node("Center/Menu/Continue") as Button).disabled)
	assert_false((title.get_node("Center/Menu/DeleteSave") as Button).disabled, "it can be deleted")
	title.call("_new_game")
	var confirm := title.get_node("ConfirmNewGame") as ConfirmationDialog
	assert_true(confirm.visible, "a new game asks before replacing it")
	assert_string_contains(confirm.dialog_text, "cannot open")
	assert_true(FileAccess.file_exists(SaveManager.save_path))
	confirm.hide()
	SaveManager.delete_slot(1)
	SaveManager.save_directory = save_directory
	SaveManager.select_slot(active_slot)
