extends GutTest

## What a run counts (`RunTallyData`), the best of any run the profile keeps,
## the report a run leaves when it ends and the node that tells it the player
## (`RunSummary`).

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const BEST_FLAG := &"test:most_foes"
const TEST_PROFILE := "user://test_run_tallies/profile.json"

var _world: Dictionary
var _profile: Dictionary
var _profile_path: String

func before_each() -> void:
	_world = WorldState.to_save_data()
	_profile = GameProfile.to_save_data()
	_profile_path = GameProfile.profile_path
	GameProfile.profile_path = TEST_PROFILE
	WorldState.clear()
	GameProfile.load_save_data({})
	var boon := BoonData.new()
	boon.id = &"fixture_keen"
	boon.display_name = "Keen"
	boon.actions = PackedStringArray(["ADD_FLAG test:keen 1"])
	ContentFixture.use(self, [
		_tally(&"fixture_depth", "Depth", 10),
		_tally(&"fixture_foes", "Foes", 20, BEST_FLAG),
		boon,
	])

func after_each() -> void:
	InputLock.clear()
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world)
	GameProfile.load_save_data(_profile)
	GameProfile.profile_path = _profile_path
	for path: String in [TEST_PROFILE, TEST_PROFILE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _tally(tally_id: StringName, tally_name: String, order: int, best_flag := &"") -> RunTallyData:
	var tally := RunTallyData.new()
	tally.id = tally_id
	tally.display_name = tally_name
	tally.order = order
	tally.best_flag = best_flag
	return tally

func test_a_run_counts_its_tallies_until_it_ends() -> void:
	watch_signals(RunState)
	assert_eq(RunState.add_tally(&"fixture_foes"), 0, "no run goes on")
	RunState.start_run()
	assert_eq(RunState.add_tally(&"fixture_foes"), 1)
	assert_eq(RunState.add_tally(&"fixture_foes", 2), 3)
	assert_signal_emitted_with_parameters(RunState, "tally_changed", [&"fixture_foes", 3])
	assert_eq(RunState.raise_tally(&"fixture_depth", 4), 4)
	assert_eq(RunState.raise_tally(&"fixture_depth", 2), 4, "a raise never lowers it")
	assert_eq(RunTallyData.find(&"fixture_foes").get_value(), 3)
	RunState.end_run(RunService.OUTCOME_RETURNED)
	assert_eq(RunState.get_tally(&"fixture_foes"), 0, "gone with the run")
	RunState.start_run()
	assert_eq(RunState.get_tally(&"fixture_depth"), 0, "each run counts anew")

func test_the_profile_keeps_the_best_of_any_run() -> void:
	RunState.start_run()
	RunState.add_tally(&"fixture_foes", 5)
	assert_eq(GameProfile.get_int(BEST_FLAG), 5)
	assert_false(RunState.beat_best(&"fixture_foes"), "the first run sets the best, it beats none")
	RunState.end_run(RunService.OUTCOME_DEFEATED)
	RunState.start_run()
	RunState.add_tally(&"fixture_foes", 4)
	assert_eq(GameProfile.get_int(BEST_FLAG), 5, "a run below the best leaves it")
	assert_false(RunState.beat_best(&"fixture_foes"))
	RunState.add_tally(&"fixture_foes", 3)
	assert_eq(GameProfile.get_int(BEST_FLAG), 7)
	assert_true(RunState.beat_best(&"fixture_foes"))
	assert_eq(RunTallyData.find(&"fixture_foes").get_best(), 7)
	assert_eq(RunTallyData.find(&"fixture_depth").get_best(), 0, "a tally without a best flag keeps none")

func test_a_run_that_ends_leaves_a_report_of_its_tallies_and_boons() -> void:
	RunState.start_run()
	RunState.add_tally(&"fixture_foes", 2)
	RunState.end_run(RunService.OUTCOME_RETURNED)
	RunState.start_run()
	RunState.add_tally(&"fixture_foes", 3)
	RunState.raise_tally(&"fixture_depth", 6)
	RunState.take_boon(&"fixture_keen")
	assert_null(RunState.get_last_report(), "a run that goes on has no report")
	RunState.end_run(RunService.OUTCOME_DEFEATED)
	var report := RunState.get_last_report()
	assert_eq(report.run, 2)
	assert_eq(report.outcome, RunService.OUTCOME_DEFEATED)
	assert_eq(report.title, "Run 2 · Defeated")
	assert_eq(report.lines, PackedStringArray(["Depth: 6", "Foes: 3 · New best", "Boons: Keen"]), "in the tallies' order")
	RunState.start_run()
	assert_null(RunState.get_last_report(), "a new run drops it")
	RunState.end_run(RunService.OUTCOME_ABANDONED)
	assert_null(RunState.get_last_report(), "an abandoned run leaves none")

func test_a_game_names_its_own_outcomes() -> void:
	RunState.outcome_names[&"fixture_escaped"] = "Escaped"
	RunState.start_run()
	RunState.end_run(&"fixture_escaped")
	RunState.outcome_names.erase(&"fixture_escaped")
	assert_eq(RunState.get_last_report().title, "Run 1 · Escaped")
	assert_eq(RunState.get_last_report().lines, PackedStringArray(), "a run that raised nothing tells nothing more")
	WorldState.clear()
	assert_null(RunState.get_last_report(), "a cleared or loaded world drops it")

func test_rule_keys_count_and_ask_about_a_tally() -> void:
	assert_false(GameRules.run_actions(PackedStringArray(["ADD_RUN_TALLY fixture_foes"])), "no run goes on")
	RunState.start_run()
	assert_true(GameRules.run_actions(PackedStringArray(["ADD_RUN_TALLY fixture_foes", "ADD_RUN_TALLY fixture_foes 2"])))
	assert_eq(RunState.get_tally(&"fixture_foes"), 3)
	assert_true(GameRules.check("RUN_TALLY_AT_LEAST fixture_foes 3"))
	assert_false(GameRules.check("RUN_TALLY_AT_LEAST fixture_foes 4"))
	assert_eq(GameRules.describe("RUN_TALLY_AT_LEAST fixture_foes 4"), PackedStringArray(["Foes in one run: 4"]))

func test_the_summary_tells_the_report_once_the_player_is_free() -> void:
	RunState.start_run()
	RunState.add_tally(&"fixture_foes", 2)
	RunState.end_run(RunService.OUTCOME_RETURNED)
	InputLock.lock(&"test:busy")
	var summary := RunSummary.new()
	add_child_autofree(summary)
	watch_signals(summary)
	await wait_process_frames(2)
	assert_null(summary.get_menu(), "it waits while something holds the controls")
	InputLock.unlock(&"test:busy")
	await wait_process_frames(2)
	var menu := summary.get_menu()
	assert_true(menu.is_open())
	assert_eq((menu.get_node("%Title") as Label).text, "Run 1 · Returned")
	assert_eq(menu.get_body(), "Foes: 2")
	assert_eq(menu.get_choice_ids(), [ChoiceMenu.OK_ID] as Array[StringName])
	assert_true(menu.choose(ChoiceMenu.OK_ID))
	assert_signal_emitted(summary, "report_read")
	assert_false(summary.show_report(), "each report shows once")

func test_the_summary_tells_a_run_that_ends_while_it_is_there() -> void:
	var summary := RunSummary.new()
	add_child_autofree(summary)
	await wait_process_frames(1)
	assert_null(summary.get_menu())
	RunState.start_run()
	RunState.end_run(RunService.OUTCOME_RETURNED)
	await wait_process_frames(2)
	assert_true(summary.get_menu().is_open())
	summary.get_menu().close()

func test_a_tally_names_itself() -> void:
	var nameless := RunTallyData.new()
	nameless.id = &"fixture_nameless"
	assert_eq(nameless.find_problems(ContentRegistry.active), PackedStringArray(["has no display name"]))
	assert_eq(RunTallyData.find_all().map(func(tally: RunTallyData) -> StringName: return tally.id), [&"fixture_depth", &"fixture_foes"])
