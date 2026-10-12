extends GutTest

## The hints a player reads once (`HintData`): `SHOW_HINT` shows one unless it
## showed before in any save or the player turned hints off, and its text
## names each control as the device in use performs it.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TEST_PATH := "user://test_hints/profile.json"

var _saved_path: String
var _saved: Dictionary
var _hints_setting: bool
var _shown: Array[String] = []

func before_each() -> void:
	_saved_path = GameProfile.profile_path
	_saved = GameProfile.to_save_data()
	_hints_setting = GameSettings.hints
	GameProfile.profile_path = TEST_PATH
	GameProfile.load_save_data({})
	GameSettings.hints = true
	_shown.clear()
	GameEvents.hint_requested.connect(_on_hint)
	ContentFixture.use(self, [_hint(&"fixture_walk", "Walk with {move}, talk with {interact}.")])

func after_each() -> void:
	GameEvents.hint_requested.disconnect(_on_hint)
	ContentRegistry.active = ContentDB
	GameSettings.hints = _hints_setting
	GameProfile.load_save_data(_saved)
	GameProfile.write_now()
	GameProfile.profile_path = _saved_path
	for path: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_a_hint_names_each_control_as_the_device_in_use_performs_it() -> void:
	var expected := "Walk with %s, talk with %s." % [InputPrompts.get_move_prompt(), InputPrompts.get_action_prompt(&"interact")]
	assert_eq(HintData.find(&"fixture_walk").get_message(), expected)
	assert_eq(HintData.get_controls("{interact} {move} {interact}"), PackedStringArray(["interact", "move"]))

func test_a_hint_shows_once_across_every_save() -> void:
	assert_false(GameRules.check("HINT_SHOWN fixture_walk"))
	assert_true(GameRules.run_actions(PackedStringArray(["SHOW_HINT fixture_walk"])))
	assert_eq(_shown.size(), 1)
	assert_true(GameRules.check("HINT_SHOWN fixture_walk"))
	assert_true(GameRules.run_actions(PackedStringArray(["SHOW_HINT fixture_walk"])), "a hint that showed still succeeds")
	assert_eq(_shown.size(), 1, "and stays quiet")
	assert_true(GameProfile.get_bool(HintData.get_shown_flag(&"fixture_walk")), "the profile keeps it, not a save's world")

func test_no_hint_shows_while_hints_are_off_and_one_passed_over_shows_once_they_are_on() -> void:
	GameSettings.hints = false
	assert_true(GameRules.run_actions(PackedStringArray(["SHOW_HINT fixture_walk"])))
	assert_eq(_shown.size(), 0)
	assert_false(GameRules.check("HINT_SHOWN fixture_walk"))
	GameSettings.hints = true
	GameRules.run_actions(PackedStringArray(["SHOW_HINT fixture_walk"]))
	assert_eq(_shown.size(), 1)

func test_content_names_hints_that_exist_and_controls_the_game_has() -> void:
	assert_eq(GameRules.validate_actions(PackedStringArray(["SHOW_HINT fixture_walk"])), PackedStringArray())
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["SHOW_HINT fixture_swim"]))), "unknown hint 'fixture_swim'")
	assert_eq(HintData.find(&"fixture_walk").find_problems(ContentRegistry.active), PackedStringArray())
	assert_eq(_hint(&"fixture_empty", " ").find_problems(ContentRegistry.active), PackedStringArray(["has no text"]))
	assert_eq(_hint(&"fixture_fly", "Fly with {fixture_fly}.").find_problems(ContentRegistry.active), PackedStringArray(["names unknown control 'fixture_fly'"]))

func _hint(id: StringName, text: String) -> HintData:
	var hint := HintData.new()
	hint.id = id
	hint.text = text
	return hint

func _on_hint(message: String) -> void:
	_shown.append(message)
