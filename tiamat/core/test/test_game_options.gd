extends GutTest

## The choices a game or a module leaves to the player (`GameOption`,
## `GameOptions`): each holds only a value it takes, a game's replaces a
## module's of the same id and what is wrong is named, the player's values
## save and load with the settings (an option the game no longer declares
## keeps its value in the file), a reset gives the defaults back, and the
## settings menu shows a row for each that sets it.

const TEST_PATH := "user://game_options_test.json"

var _options: GameOptions

func before_each() -> void:
	_options = GameSettings.options
	JsonFile.remove(TEST_PATH)

func after_each() -> void:
	GameSettings.options = _options
	JsonFile.remove(TEST_PATH)

func test_an_option_holds_only_a_value_it_takes() -> void:
	var switch := GameOption.new_switch(&"subtitles", "Subtitles", true)
	assert_eq(switch.get_default(), true)
	assert_eq(switch.accept(false, true), false)
	assert_eq(switch.accept(1, true), true, "a number is no switch's value")
	var pick := GameOption.new_choice(&"difficulty", "Difficulty", PackedStringArray(["Easy", "Normal", "Hard"]), 1)
	assert_eq(pick.get_default(), "Normal")
	assert_eq(pick.accept("Hard", "Normal"), "Hard")
	assert_eq(pick.accept("Nightmare", "Normal"), "Normal", "a choice it does not offer")
	assert_eq(pick.accept(2, "Normal"), "Normal", "a choice is named, not counted")
	var number := GameOption.new_range(&"zoom", "Zoom", 1.0, 3.0, 0.5, 2.0)
	assert_eq(number.get_default(), 2.0)
	assert_eq(number.accept(2.4, 2.0), 2.5, "held to its steps")
	assert_eq(number.accept(9, 2.0), 3.0, "and to its range")
	assert_eq(number.accept("2", 2.0), 2.0, "text is no number")
	for option: GameOption in [switch, pick, number]:
		assert_eq(option.find_problems(), PackedStringArray())

func test_a_game_s_option_replaces_a_module_s_and_what_is_wrong_is_named() -> void:
	var module_option := GameOption.new_switch(&"hints", "Hints", true)
	var game_option := GameOption.new_switch(&"hints", "Hints", false)
	var other := GameOption.new_switch(&"music_box", "Music Box")
	var resolved := GameOptions.resolve([game_option, other], [module_option])
	assert_eq(resolved.size(), 2)
	assert_same(resolved[0], game_option, "the game's comes first and replaces the module's")
	assert_same(resolved[1], other)
	assert_eq(GameOptions.find_problems([game_option, other], [module_option]), PackedStringArray(), "a game may replace a module's option")
	var empty_range := GameOption.new_range(&"zoom", "Zoom", 2.0, 2.0, 0.5, 2.0)
	var lone := GameOption.new_choice(&"mode", "Mode", PackedStringArray(["Only"]))
	var outside := GameOption.new_choice(&"speed", "Speed", PackedStringArray(["Slow", "Fast"]), 5)
	var twice := GameOption.new_choice(&"side", "Side", PackedStringArray(["Left", "Left"]))
	var unnamed := GameOption.new_switch(&"quiet", "")
	var problems := GameOptions.find_problems([null, other, other, empty_range, lone, outside, twice, unnamed, GameOption.new()], [module_option, module_option])
	for expected: String in [
			"GameDefinition.options has an entry that is not a GameOption",
			"option 'music_box' is listed twice",
			"two modules declare option 'hints'",
			"option 'zoom' has an empty range",
			"option 'mode' offers fewer than two choices",
			"option 'speed' starts on a choice it does not offer",
			"option 'side' has an empty or repeated choice",
			"option 'quiet' has no name to show",
			"an option has no id"]:
		assert_has(problems, expected)

func test_the_player_s_options_save_and_load_with_the_settings_and_a_reset_gives_the_defaults() -> void:
	JsonFile.write(TEST_PATH, {"settings_version": GameSettingsService.SETTINGS_VERSION, "options": {"dropped_option": 3, "zoom": "far"}})
	var settings := _settings()
	settings.load_settings()
	assert_eq(settings.get_option(&"zoom"), 2.0, "a value the option does not take keeps the default")
	var told: Array = []
	settings.option_changed.connect(func(id: StringName, value: Variant) -> void: told.append([id, value]))
	settings.set_option(&"subtitles", false)
	settings.set_option(&"difficulty", "Hard")
	settings.set_option(&"zoom", 2.6)
	settings.set_option(&"zoom", 2.5)
	assert_eq(told, [[&"subtitles", false], [&"difficulty", "Hard"], [&"zoom", 2.5]], "each change is told once, as the option holds it")
	settings.save_settings()
	var later := _settings()
	later.load_settings()
	assert_eq(later.get_option(&"subtitles"), false)
	assert_eq(later.get_option(&"difficulty"), "Hard")
	assert_eq(later.get_option(&"zoom"), 2.5)
	assert_eq(later.to_data()["options"].get("dropped_option"), 3.0, "an option the game dropped keeps the player's value in the file")
	later.reset_all()
	assert_eq(later.get_option(&"subtitles"), true)
	assert_eq(later.get_option(&"difficulty"), "Normal")
	assert_eq(later.get_option(&"zoom"), 2.0)

func test_the_settings_menu_shows_a_row_for_each_option_that_sets_it() -> void:
	GameSettings.options = GameOptions.new(_fixture_options())
	var menu := (load("res://tiamat/core/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	add_child_autofree(menu)
	menu.open()
	await wait_process_frames(1)
	var rows := menu.option_rows
	assert_true(rows.visible)
	assert_true(rows.is_visible_in_tree(), "on the main page")
	var check := rows.get_input(&"subtitles") as CheckButton
	var select := rows.get_input(&"difficulty") as OptionButton
	var slider := rows.get_input(&"zoom") as HSlider
	assert_not_null(check)
	assert_not_null(select)
	assert_not_null(slider)
	assert_true(check.button_pressed, "each shows the player's value")
	assert_eq(select.get_item_text(select.selected), "Normal")
	assert_eq(slider.value, 2.0)
	check.button_pressed = false
	assert_eq(GameSettings.get_option(&"subtitles"), false, "a row sets its option")
	select.item_selected.emit(2)
	assert_eq(GameSettings.get_option(&"difficulty"), "Hard")
	slider.value = 3.0
	assert_eq(GameSettings.get_option(&"zoom"), 3.0)
	GameSettings.set_option(&"subtitles", true)
	assert_true(check.button_pressed, "a change made elsewhere shows")
	GameSettings.reset_all()
	assert_eq(select.get_item_text(select.selected), "Normal", "and so does a reset")
	assert_eq(slider.value, 2.0)
	menu.close()

func test_a_game_without_options_shows_no_rows() -> void:
	GameSettings.options = GameOptions.new()
	var menu := (load("res://tiamat/core/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	add_child_autofree(menu)
	assert_false(menu.option_rows.visible)
	assert_eq(menu.option_rows.get_child_count(), 0)

func _fixture_options() -> Array[GameOption]:
	return [
		GameOption.new_switch(&"subtitles", "Subtitles", true),
		GameOption.new_choice(&"difficulty", "Difficulty", PackedStringArray(["Easy", "Normal", "Hard"]), 1),
		GameOption.new_range(&"zoom", "Zoom", 1.0, 3.0, 0.5, 2.0),
	]

# Settings of the test's own file with the fixture options.
func _settings() -> GameSettingsService:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	settings.options = GameOptions.new(_fixture_options())
	add_child_autofree(settings)
	return settings
