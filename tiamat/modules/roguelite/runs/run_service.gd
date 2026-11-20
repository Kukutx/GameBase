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
##
## A run counts tallies (`RunTallyData`: the creatures it defeated, the depth
## it reached), which may raise the best of any run in the player's profile,
## and a run that ended, not abandoned, leaves a report of them and of its
## boons (`get_last_report()`) that a `RunSummary` shows the player once they
## are back.

signal run_started(run: int)
signal run_ended(run: int, outcome: StringName)
## The run took boon `boon_id` (`take_boon()`).
signal boon_taken(boon_id: StringName)
## The run's tally `tally_id` now stands at `value` (`add_tally()`,
## `raise_tally()`).
signal tally_changed(tally_id: StringName, value: int)

const OUTCOME_RETURNED := &"returned"
const OUTCOME_DEFEATED := &"defeated"
const OUTCOME_ABANDONED := &"abandoned"

const COUNT_KEY := &"run:count"
const ACTIVE_KEY := &"run:active"
## The run's own values are kept under this prefix.
const VALUE_PREFIX := "run:value:"
## How many times the run took each boon: a run value `boon:<boon id>`.
const BOON_PREFIX := "boon:"
## What each tally of the run stands at: a run value `tally:<tally id>`.
const TALLY_PREFIX := "tally:"
## The best of a tally the run beat, as it stood before: a run value
## `beat:<tally id>`, set the first time the run beats it.
const BEAT_PREFIX := "beat:"

## What a run that ended, not abandoned, brought, as the player reads it: its
## `title` ("Run 3 · Returned") and `lines`, each tally it raised and its
## boons (`RunService.describe_run()`). `seen` once the player saw it.
class Report:
	extends RefCounted

	var run: int
	var outcome: StringName
	var title: String
	var lines: PackedStringArray
	var seen := false

	func _init(report_run: int, report_outcome: StringName, report_title: String, report_lines: PackedStringArray) -> void:
		run = report_run
		outcome = report_outcome
		title = report_title
		lines = report_lines

## Whether the game cannot be saved while a run goes on.
var blocks_saves := true
## Why it cannot, as the player reads it (translated when shown); empty says
## "Finish the run to save".
var save_block_reason := ""
## The names of the outcomes a game ends its runs with besides returned and
## defeated, as outcome -> text (translated when shown) for a run's report.
var outcome_names: Dictionary[StringName, String] = {}

# The run's boons, boon id -> times taken, read again once the world changed
# them (the player's speed asks for its stat every frame).
var _boons: Dictionary[StringName, int] = {}
var _boons_read := false
var _last_report: Report = null

func _ready() -> void:
	GameSession.passing_out.connect(_on_passing_out)
	WorldState.changed.connect(_on_world_changed)

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
	_last_report = null
	WorldState.set_value(COUNT_KEY, run)
	WorldState.set_value(ACTIVE_KEY, true)
	run_started.emit(run)
	return run

## Ends the run with `outcome`; false when no run goes on.
func end_run(outcome: StringName) -> bool:
	if not is_active():
		return false
	WorldState.set_value(ACTIVE_KEY, false)
	var run := get_run()
	_last_report = null
	if outcome != OUTCOME_ABANDONED:
		_last_report = Report.new(run, outcome, tr("Run %d · %s") % [run, get_outcome_name(outcome)], describe_run())
	# What lasted the run is still there while `run_ended` is handled (a game
	# banks the run's gold when the player returned).
	run_ended.emit(run, outcome)
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

## How many times this run took boon `boon_id`.
func get_boon_stacks(boon_id: StringName) -> int:
	return int(_read_boons().get(boon_id, 0))

## The boons this run took, by id, in the order of their ids.
func get_boons() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_read_boons().keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids

## The boons this run took as the player reads them, in the order of their
## ids: each by its name, with how many times when more than once
## ("Ember Edge ×2").
func describe_boons() -> PackedStringArray:
	var parts := PackedStringArray()
	for boon_id: StringName in get_boons():
		var boon := BoonData.find(boon_id)
		var name := boon.get_display_name() if boon != null else String(boon_id)
		var stacks := get_boon_stacks(boon_id)
		parts.append(tr("%s ×%d") % [name, stacks] if stacks > 1 else name)
	return parts

## How many boons this run took, each as many times as it took it.
func get_boon_count() -> int:
	var total := 0
	for stacks: int in _read_boons().values():
		total += stacks
	return total

## What tally `tally_id` stands at in the run going on.
func get_tally(tally_id: StringName) -> int:
	return WorldState.get_int(_value_key(_tally_key(tally_id)))

## Adds `amount` to tally `tally_id` of the run going on and gives what it
## stands at then; ignored, 0, while no run goes on.
func add_tally(tally_id: StringName, amount := 1) -> int:
	return _set_tally(tally_id, get_tally(tally_id) + amount)

## Raises tally `tally_id` of the run going on to `value` when it stands
## lower (the depth the run reached) and gives what it stands at then;
## ignored, 0, while no run goes on.
func raise_tally(tally_id: StringName, value: int) -> int:
	return _set_tally(tally_id, maxi(get_tally(tally_id), value))

## Whether the run going on raised tally `tally_id` past the best an earlier
## run raised it to (`RunTallyData.best_flag`), not counting the first run
## that raised it at all.
func beat_best(tally_id: StringName) -> bool:
	return WorldState.get_int(_value_key(_beat_key(tally_id))) > 0

## The run going on as the player reads it: each tally it raised, in the order
## of the tallies, with what it stands at ("Creatures Defeated: 12", marked
## when it beat the best of the runs before), and the boons it took.
func describe_run() -> PackedStringArray:
	var lines := PackedStringArray()
	for tally: RunTallyData in RunTallyData.find_all():
		var value := get_tally(tally.id)
		if value > 0:
			var line := tr("%s: %d · New best") if beat_best(tally.id) else tr("%s: %d")
			lines.append(line % [tally.get_display_name(), value])
	var boons := describe_boons()
	if not boons.is_empty():
		lines.append(tr("Boons: %s") % ", ".join(boons))
	return lines

## The name of `outcome` as the player reads it.
func get_outcome_name(outcome: StringName) -> String:
	match outcome:
		OUTCOME_RETURNED:
			return tr("Returned")
		OUTCOME_DEFEATED:
			return tr("Defeated")
		OUTCOME_ABANDONED:
			return tr("Abandoned")
	return tr(outcome_names.get(outcome, String(outcome)))

## The report of the last run that ended this session, not abandoned, or null:
## once a run starts again, or the world is loaded or cleared, there is none.
func get_last_report() -> Report:
	return _last_report

## Up to `count` boons of `pool` (`BoonData.pool`; empty, the common one)
## the run may take now (`BoonData.can_take()`), none twice, each as likely as
## its weight, rolled from the run's stream named `offer:<name>`: the same run
## and name offer the same boons as long as the run may take them, so leaving
## and coming back offers no others.
func offer_boons(count: int, name: String, pool := &"") -> Array[BoonData]:
	var offered: Array[BoonData] = []
	if not is_active():
		return offered
	var candidates: Array[BoonData] = []
	candidates.assign(BoonData.find_pool(pool).filter(func(boon: BoonData) -> bool: return boon.can_take()))
	var rng := stream("offer:%s" % name)
	while offered.size() < count and not candidates.is_empty():
		var weights := PackedFloat64Array()
		for boon: BoonData in candidates:
			weights.append(boon.weight)
		offered.append(candidates.pop_at(rng.pick_weighted(weights)))
	return offered

## Takes boon `boon_id` in the run going on: runs its actions and counts it;
## false when the run may not take it (`BoonData.can_take()`) or its actions
## cannot run.
func take_boon(boon_id: StringName) -> bool:
	var boon := BoonData.find(boon_id)
	if boon == null or not boon.can_take():
		return false
	if not boon.actions.is_empty() and not GameRules.run_actions(boon.actions):
		return false
	set_value(_boon_key(boon_id), get_boon_stacks(boon_id) + 1)
	boon_taken.emit(boon_id)
	return true

## `GameStats` source: the product of the run's boons' multipliers of `stat`,
## each once for every time the run took it.
func get_stat_multiplier(stat: StringName) -> float:
	var result := 1.0
	var boons := _read_boons()
	for boon_id: StringName in boons:
		var boon := BoonData.find(boon_id)
		if boon != null and boon.multipliers.has(stat):
			result *= pow(boon.multipliers[stat], boons[boon_id])
	return result

## `GameStats` source: the sum of the run's boons' bonuses to `stat`, each
## once for every time the run took it.
func get_stat_bonus(stat: StringName) -> float:
	var result := 0.0
	var boons := _read_boons()
	for boon_id: StringName in boons:
		var boon := BoonData.find(boon_id)
		if boon != null:
			result += float(boon.bonuses.get(stat, 0.0)) * boons[boon_id]
	return result

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

func _boon_key(boon_id: StringName) -> StringName:
	return StringName(BOON_PREFIX + String(boon_id))

func _tally_key(tally_id: StringName) -> StringName:
	return StringName(TALLY_PREFIX + String(tally_id))

func _beat_key(tally_id: StringName) -> StringName:
	return StringName(BEAT_PREFIX + String(tally_id))

func _set_tally(tally_id: StringName, value: int) -> int:
	if not is_active():
		return 0
	if value != get_tally(tally_id):
		set_value(_tally_key(tally_id), value)
		_raise_best(tally_id, value)
		tally_changed.emit(tally_id, value)
	return value

# Raises the profile's best of tally `tally_id` to `value`, keeping the best it
# beat the first time the run beats it.
func _raise_best(tally_id: StringName, value: int) -> void:
	var tally := RunTallyData.find(tally_id)
	if tally == null or tally.best_flag == &"":
		return
	var best := tally.get_best()
	if value <= best:
		return
	if get_value(_beat_key(tally_id)) == null:
		set_value(_beat_key(tally_id), best)
	GameProfile.set_flag(tally.best_flag, value)

func _read_boons() -> Dictionary[StringName, int]:
	if _boons_read:
		return _boons
	_boons.clear()
	var prefix := VALUE_PREFIX + BOON_PREFIX
	for key: StringName in WorldState.get_keys(prefix):
		var stacks := WorldState.get_int(key)
		if stacks > 0:
			_boons[StringName(String(key).trim_prefix(prefix))] = stacks
	_boons_read = true
	return _boons

func _on_world_changed(key: StringName, _value: Variant) -> void:
	if key == &"":
		_last_report = null
	if key == &"" or String(key).begins_with(VALUE_PREFIX + BOON_PREFIX):
		_boons_read = false
		GameStats.notify_changed()
