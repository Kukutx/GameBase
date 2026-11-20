extends GutTest

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const STATION_SCENE := preload("res://tiamat/core/minigames/minigame_station.tscn")
const FIRST := &"fixture_first_battle"
const SECOND := &"fixture_second_battle"
const PROFILE_PATH := "user://test_minigame_picker/profile.json"

var _saved_path: String
var _saved_profile: Dictionary

## A minigame the test ends itself.
class _FixtureMiniGame:
	extends MiniGame

func before_each() -> void:
	WorldState.clear()
	_saved_path = GameProfile.profile_path
	_saved_profile = GameProfile.to_save_data()
	GameProfile.profile_path = PROFILE_PATH
	GameProfile.load_save_data({})
	var minigame := _FixtureMiniGame.new()
	var scene := PackedScene.new()
	scene.pack(minigame)
	minigame.free()
	var first := MiniGameDefinition.new()
	first.id = FIRST
	first.scene = scene
	first.display_name = "First Battle"
	first.description = "Hold the ford."
	first.score_name = "Units Left"
	var second := MiniGameDefinition.new()
	second.id = SECOND
	second.scene = scene
	second.display_name = "Second Battle"
	second.condition = "MINIGAME_WON %s" % FIRST
	ContentFixture.use(self, [first, second])

func after_each() -> void:
	ContentRegistry.active = ContentDB
	MiniGameHost.cancel()
	InputLock.clear()
	WorldState.clear()
	GameProfile.load_save_data(_saved_profile)
	GameProfile.profile_path = _saved_path
	for path: String in [PROFILE_PATH, PROFILE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish(result: MiniGameResult) -> void:
	(MiniGameHost.get_active() as MiniGame).finish(result)
	await get_tree().process_frame

func _station() -> MiniGameStation:
	var station := STATION_SCENE.instantiate() as MiniGameStation
	station.choices.assign([FIRST, SECOND])
	station.title = "Plan the Battle"
	add_child_autofree(station)
	return station

func test_a_win_counts_in_the_save_and_a_loss_or_a_cancel_does_not() -> void:
	var first := MiniGameDefinition.find(FIRST)
	(func() -> void: await MiniGameHost.run(FIRST)).call()
	await _finish(MiniGameResult.lost())
	(func() -> void: await MiniGameHost.run(FIRST)).call()
	MiniGameHost.cancel()
	await get_tree().process_frame
	assert_eq(first.get_wins(), 0)
	assert_false(GameRules.check("MINIGAME_WON %s" % FIRST))
	(func() -> void: await MiniGameHost.run(FIRST)).call()
	await _finish(MiniGameResult.won())
	assert_eq(first.get_wins(), 1)
	assert_eq(WorldState.get_int(MiniGameDefinition.wins_key(FIRST)), 1, "the save keeps the count")
	assert_true(GameRules.check("MINIGAME_WON %s" % FIRST))
	assert_false(GameRules.check("MINIGAME_WON %s %s" % [FIRST, SECOND]), "each must be won")

func test_a_minigame_s_condition_opens_it_and_says_what_it_needs() -> void:
	var second := MiniGameDefinition.find(SECOND)
	assert_eq(GameRules.validate_query(second.condition), PackedStringArray())
	assert_eq(GameRules.validate_query("MINIGAME_WON fixture_no_such_battle").size(), 1, "an unknown minigame fails validation")
	assert_false(second.is_open())
	assert_eq(second.get_requirements(), PackedStringArray(["Win First Battle"]))
	WorldState.add_int(MiniGameDefinition.wins_key(FIRST), 1)
	assert_true(second.is_open())

func test_the_station_lists_its_choices_the_locked_one_saying_what_it_needs() -> void:
	var station := _station()
	assert_eq(station.find_scene_problems(ContentRegistry.active, null), PackedStringArray())
	(func() -> void: await station.pick()).call()
	var picker := station.get_picker()
	assert_true(picker.is_open())
	assert_eq((picker.get_node("%Title") as Label).text, "Plan the Battle")
	var buttons := picker.get_buttons()
	assert_eq(buttons.map(func(button: Button) -> String: return button.text), ["First Battle", "Second Battle"])
	assert_eq(buttons.map(func(button: Button) -> bool: return button.disabled), [false, true])
	assert_eq(picker.get_note(FIRST), "Hold the ford.")
	assert_eq(picker.get_note(SECOND), "Locked: Win First Battle")
	await get_tree().process_frame
	assert_true(buttons[0].has_focus(), "the focus is on the first one open")
	picker.close()
	assert_false(picker.is_open())

func test_a_won_minigame_is_marked_and_opens_the_next() -> void:
	WorldState.add_int(MiniGameDefinition.wins_key(FIRST), 1)
	var station := _station()
	(func() -> void: await station.pick()).call()
	var buttons := station.get_picker().get_buttons()
	assert_eq(buttons[0].text, "First Battle (Won)")
	assert_false(buttons[1].disabled)
	assert_eq(station.get_picker().get_note(SECOND), "", "an open one without a description has no line")

func test_interact_plays_the_minigame_the_player_picks() -> void:
	var station := _station()
	var outcome := {}
	station.played.connect(func(result: MiniGameResult) -> void: outcome["result"] = result)
	station.interactable.interacted.emit(null)
	var picker := station.get_picker()
	assert_true(picker.is_open())
	assert_false(MiniGameHost.is_running(), "nothing runs before the player picks")
	picker.get_buttons()[0].pressed.emit()
	assert_false(picker.is_open())
	assert_eq(MiniGameHost.get_active_id(), FIRST)
	await _finish(MiniGameResult.won())
	assert_true((outcome["result"] as MiniGameResult).success)

func test_closing_the_list_plays_nothing() -> void:
	var station := _station()
	var outcome := {}
	(func() -> void: outcome["picked"] = await station.pick()).call()
	station.get_picker().close()
	assert_eq(outcome.get("picked"), &"")
	assert_false(MiniGameHost.is_running())

func test_a_choice_the_content_lacks_or_that_has_no_name_is_a_problem() -> void:
	var station := _station()
	station.choices.assign([FIRST, &"fixture_no_such_battle"])
	MiniGameDefinition.find(FIRST).display_name = ""
	assert_eq(station.find_scene_problems(ContentRegistry.active, null), PackedStringArray([
		"station '%s' offers minigame '%s', which has no display name" % [station.name, FIRST],
		"station '%s' offers unknown minigame 'fixture_no_such_battle'" % station.name,
	]))

func test_the_best_score_stays_in_the_profile_and_shows_under_its_name() -> void:
	var first := MiniGameDefinition.find(FIRST)
	(func() -> void: await MiniGameHost.run(FIRST)).call()
	await _finish(MiniGameResult.won(3))
	(func() -> void: await MiniGameHost.run(FIRST)).call()
	await _finish(MiniGameResult.lost(1))
	assert_eq(first.get_best_score(), 3, "a lower score leaves the best")
	(func() -> void: await MiniGameHost.run(FIRST)).call()
	MiniGameHost.cancel()
	await get_tree().process_frame
	assert_eq(GameProfile.get_int(MiniGameDefinition.best_score_key(FIRST)), 3, "the profile keeps it for every save")
	WorldState.clear()
	assert_eq(first.get_best_score(), 3, "a new save keeps it too")
	var station := _station()
	(func() -> void: await station.pick()).call()
	assert_eq(station.get_picker().get_note(FIRST), "Hold the ford.\nBest Units Left: 3")
	MiniGameDefinition.find(SECOND).score_name = "Units Left"
	assert_eq(MiniGamePicker.note_text(MiniGameDefinition.find(SECOND)), "Locked: Win First Battle", "a locked one shows what it needs alone")
