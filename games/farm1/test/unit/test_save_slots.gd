extends GutTest

func test_title_screen_shows_the_slot_summary() -> void:
	var scene := load("res://game/ui/title_screen.tscn") as PackedScene
	var title := scene.instantiate()
	autofree(title)
	assert_not_null(title.get_node_or_null("Center/Menu/SaveSlot"))
	assert_not_null(title.get_node_or_null("Center/Menu/SlotInfo"))
	assert_not_null(title.get_node_or_null("Center/Menu/DeleteSave"))
	assert_not_null(title.get_node_or_null("ConfirmDelete"))
	var text := String(title.call("_format_slot_summary", {
		"season": "Autumn",
		"day_of_season": 12,
		"day": 68,
		"minute_of_day": 600,
		"money": 4321,
		"recoverable": true,
		"recovery_source": "backup",
	}))
	assert_eq(text, "Autumn 12 · Day 68 · 10:00 · 4321g · backup available")
