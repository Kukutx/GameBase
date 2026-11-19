class_name RunService
extends Node

## Runs: a stretch of play that starts, say at a dungeon's entrance, and ends
## with an outcome, the player back at camp (`OUTCOME_RETURNED`), defeated
## (`OUTCOME_DEFEATED`) or taken out of play by passing out for another cause
## (lifesim's late night), a load, a new game or the title (`OUTCOME_ABANDONED`;
## passing out then saves what the run brought, the others do not). It counts the runs a world started and keeps values
## that last one run (`set_value()`), cleared when a run starts and when it
## ends, and gives each run its own random streams (`stream()`).
##
## Its state lives in the world (`WorldState`, under `run:`), so it saves with
## it. While a run goes on the game cannot be saved, unless the game lets it
## (`blocks_saves`): a run is played through, and the save at its end keeps
## what it brought. `run_started` and `run_ended` announce each run, which
## triggers follow (`EVENT_ARG outcome returned`).

signal run_started(run: int)
signal run_ended(run: int, outcome: StringName)

const OUTCOME_RETURNED := &"returned"
const OUTCOME_DEFEATED := &"defeated"
const OUTCOME_ABANDONED := &"abandoned"

const COUNT_KEY := &"run:count"
const ACTIVE_KEY := &"run:active"
## The run's own values are kept under this prefix.
const VALUE_PREFIX := "run:value:"

## Whether the game cannot be saved while a run goes on.
var blocks_saves := true
## Why it cannot, as the player reads it (translated when shown); empty says
## "Finish the run to save".
var save_block_reason := ""

func _ready() -> void:
	GameSession.passing_out.connect(_on_passing_out)

## How many runs this world started.
func get_run() -> int:
	return SaveValues.count(WorldState.get_value(COUNT_KEY, 0))

## Whether a run goes on.
func is_active() -> bool:
	return WorldState.get_bool(ACTIVE_KEY)

## Starts the next run. A run that still goes on ends first, abandoned.
func start_run() -> int:
	if is_active():
		end_run(OUTCOME_ABANDONED)
	var run := get_run() + 1
	_clear_values()
	WorldState.set_value(COUNT_KEY, run)
	WorldState.set_value(ACTIVE_KEY, true)
	run_started.emit(run)
	return run

## Ends the run with `outcome`; false when no run goes on.
func end_run(outcome: StringName) -> bool:
	if not is_active():
		return false
	WorldState.set_value(ACTIVE_KEY, false)
	# What lasted the run is still there while `run_ended` is handled (a game
	# banks the run's gold when the player returned).
	run_ended.emit(get_run(), outcome)
	_clear_values()
	return true

## A value that lasts the run, or `default_value`.
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return WorldState.get_value(_value_key(key), default_value)

## Keeps a plain value (see `WorldState`) until the run ends; ignored while
## no run goes on.
func set_value(key: StringName, value: Variant) -> void:
	if is_active():
		WorldState.set_value(_value_key(key), value)

## A random stream of this run (`GameRandom.stream()`), `"run:<run>:<name>"`:
## the same world, run and name always roll the same.
func stream(name: String) -> GameRandomStream:
	return GameRandom.stream("run:%d:%s" % [get_run(), name])

## Why the game cannot be saved now (a save blocker), or "".
func get_save_block_reason() -> String:
	if not blocks_saves or not is_active():
		return ""
	return tr(save_block_reason) if not save_block_reason.is_empty() else tr("Finish the run to save")

## Ends a run that goes on as abandoned: something takes the player out of
## play (`GameSession.register_activity_end()`).
func abandon() -> void:
	end_run(OUTCOME_ABANDONED)

# The player lost all their health: the run ends in defeat before the session
# takes them home.
# A defeat ends the run before passing out ends the player's activities, which
# would abandon it.
func _on_passing_out(cause: StringName) -> void:
	if cause == GameSession.CAUSE_DEFEAT:
		end_run(OUTCOME_DEFEATED)

func _clear_values() -> void:
	for key: StringName in WorldState.get_keys(VALUE_PREFIX):
		WorldState.erase(key)

func _value_key(key: StringName) -> StringName:
	return StringName(VALUE_PREFIX + String(key))
