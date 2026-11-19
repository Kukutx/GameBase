class_name RogueliteRules
extends RefCounted

## Condition keys of the roguelite module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"RUN_ACTIVE", _run_active, 0, 0)
	rules.register_condition(&"RUNS_AT_LEAST", _runs_at_least, 1, 1, [GameRulesService.ARG_COUNT])

## RUN_ACTIVE: a run goes on.
static func _run_active(_args: PackedStringArray, _context: Dictionary) -> bool:
	return RunState.is_active()

## RUNS_AT_LEAST <count>: this world started at least that many runs.
static func _runs_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return RunState.get_run() >= int(args[0])
