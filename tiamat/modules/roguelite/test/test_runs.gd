extends GutTest

## Runs (`RunState`): how they start and end, what lasts one run, their random
## streams, the saves they block and their rule keys.

var _world: Dictionary
var _reason: String
var _blocks: bool

func before_each() -> void:
	_world = WorldState.to_save_data()
	_reason = RunState.save_block_reason
	_blocks = RunState.blocks_saves
	WorldState.clear()

func after_each() -> void:
	WorldState.load_save_data(_world)
	RunState.save_block_reason = _reason
	RunState.blocks_saves = _blocks

func test_a_run_starts_and_ends_with_an_outcome() -> void:
	watch_signals(RunState)
	assert_false(RunState.end_run(RunService.OUTCOME_RETURNED), "no run goes on")
	assert_eq(RunState.start_run(), 1)
	assert_true(RunState.is_active())
	assert_signal_emitted_with_parameters(RunState, "run_started", [1])
	assert_true(RunState.end_run(RunService.OUTCOME_RETURNED))
	assert_false(RunState.is_active())
	assert_signal_emitted_with_parameters(RunState, "run_ended", [1, RunService.OUTCOME_RETURNED])
	assert_eq(RunState.start_run(), 2)
	assert_eq(RunState.start_run(), 3, "a run that still went on ends first")
	assert_signal_emitted_with_parameters(RunState, "run_ended", [2, RunService.OUTCOME_ABANDONED])
	assert_eq(RunState.get_run(), 3)

func test_what_lasts_a_run_is_gone_when_it_ends() -> void:
	RunState.set_value(&"gold", 5)
	assert_null(RunState.get_value(&"gold"), "no run, nothing to keep")
	RunState.start_run()
	RunState.set_value(&"gold", 5)
	assert_eq(RunState.get_value(&"gold"), 5)
	var banked: Array[int] = []
	var bank := func(_run: int, _outcome: StringName) -> void: banked.append(int(RunState.get_value(&"gold", 0)))
	RunState.run_ended.connect(bank)
	RunState.end_run(RunService.OUTCOME_RETURNED)
	RunState.run_ended.disconnect(bank)
	assert_eq(banked, [5] as Array[int], "what the run brought is there while its end is handled")
	assert_eq(RunState.get_value(&"gold", 0), 0)
	assert_true(WorldState.get_keys(RunService.VALUE_PREFIX).is_empty())

func test_each_run_rolls_its_own_numbers() -> void:
	RunState.start_run()
	var first := RunState.stream("loot").randi()
	assert_eq(RunState.stream("loot").randi(), first, "the same run rolls the same")
	RunState.start_run()
	assert_ne(RunState.stream("loot").randi(), first)

func test_a_run_ends_in_defeat_and_when_play_is_left() -> void:
	watch_signals(RunState)
	RunState.start_run()
	# What the session announces as a defeat knocks the player out.
	GameSession.passing_out.emit(GameSession.CAUSE_DEFEAT)
	assert_signal_emitted_with_parameters(RunState, "run_ended", [1, RunService.OUTCOME_DEFEATED])
	RunState.start_run()
	GameSession.end_activities()
	assert_signal_emitted_with_parameters(RunState, "run_ended", [2, RunService.OUTCOME_ABANDONED])
	assert_false(RunState.is_active())

func test_a_run_blocks_saving_unless_the_game_lets_it() -> void:
	RunState.save_block_reason = ""
	assert_eq(RunState.get_save_block_reason(), "")
	RunState.start_run()
	assert_eq(RunState.get_save_block_reason(), "Finish the run to save")
	RunState.save_block_reason = "Return to camp to save"
	assert_eq(RunState.get_save_block_reason(), "Return to camp to save")
	RunState.blocks_saves = false
	assert_eq(RunState.get_save_block_reason(), "")

func test_rule_keys_ask_about_runs() -> void:
	assert_eq(GameRules.validate_query("RUN_ACTIVE, RUNS_AT_LEAST 2"), PackedStringArray())
	assert_false(GameRules.validate_query("RUNS_AT_LEAST 0").is_empty(), "a count of runs starts at 1")
	assert_false(GameRules.check("RUN_ACTIVE"))
	RunState.start_run()
	assert_true(GameRules.check("RUN_ACTIVE, RUNS_AT_LEAST 1"))
	assert_false(GameRules.check("RUNS_AT_LEAST 2"))
