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
