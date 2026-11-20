class_name RogueliteRules
extends RefCounted

## Condition and action keys of the roguelite module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"RUN_ACTIVE", _run_active, 0, 0)
	rules.register_condition(&"RUNS_AT_LEAST", _runs_at_least, 1, 1, [GameRulesService.ARG_COUNT], _describe_runs_at_least)
	rules.register_condition(&"BOON_TAKEN", _boon_taken, 1, -1, [BoonData.KIND], _describe_boon_taken)
	rules.register_condition(&"BOONS_AT_LEAST", _boons_at_least, 1, 1, [GameRulesService.ARG_COUNT], _describe_boons_at_least)
	rules.register_condition(&"RUN_TALLY_AT_LEAST", _run_tally_at_least, 2, 2, [RunTallyData.KIND, GameRulesService.ARG_COUNT], _describe_run_tally_at_least)
	rules.register_action(&"TAKE_BOON", _take_boon, 1, 1, [BoonData.KIND])
	rules.register_action(&"ADD_RUN_TALLY", _add_run_tally, 1, 2, [RunTallyData.KIND, GameRulesService.ARG_INT])

## RUN_ACTIVE: a run goes on.
static func _run_active(_args: PackedStringArray, _context: Dictionary) -> bool:
	return RunState.is_active()

## RUNS_AT_LEAST <count>: this world started at least that many runs.
static func _runs_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return RunState.get_run() >= int(args[0])

static func _describe_runs_at_least(args: PackedStringArray) -> String:
	return TranslationServer.translate("Runs: %d") % int(args[0])

## BOON_TAKEN <boon>...: the run going on took each of these boons.
static func _boon_taken(args: PackedStringArray, _context: Dictionary) -> bool:
	for boon_id: String in args:
		if RunState.get_boon_stacks(StringName(boon_id)) <= 0:
			return false
	return true

static func _describe_boon_taken(args: PackedStringArray) -> String:
	var names := PackedStringArray()
	for boon_id: String in args:
		names.append(GameRulesService.entry_name(BoonData.KIND, boon_id))
	return TranslationServer.translate("With %s") % GameText.list(names)

## BOONS_AT_LEAST <count>: the run going on took at least that many boons,
## each as many times as it took it.
static func _boons_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return RunState.get_boon_count() >= int(args[0])

static func _describe_boons_at_least(args: PackedStringArray) -> String:
	return TranslationServer.translate("Boons in a run: %d") % int(args[0])

## TAKE_BOON <boon>: the run going on takes the boon, as if the player picked
## it; fails when it may not (`BoonData.can_take()`).
static func _take_boon(args: PackedStringArray, _context: Dictionary) -> bool:
	return RunState.take_boon(StringName(args[0]))

## RUN_TALLY_AT_LEAST <tally> <count>: the run going on raised the tally to at
## least that much.
static func _run_tally_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return RunState.get_tally(StringName(args[0])) >= int(args[1])

static func _describe_run_tally_at_least(args: PackedStringArray) -> String:
	return TranslationServer.translate("%s in one run: %d") % [GameRulesService.entry_name(RunTallyData.KIND, args[0]), int(args[1])]

## ADD_RUN_TALLY <tally> [amount]: adds the amount, 1 when none, to the tally
## of the run going on; fails while no run goes on.
static func _add_run_tally(args: PackedStringArray, _context: Dictionary) -> bool:
	if not RunState.is_active():
		return false
	RunState.add_tally(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)
	return true
