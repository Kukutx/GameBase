class_name RunTallyData
extends ContentEntry

## A number one run keeps: the creatures it defeated, the depth it reached.
## Content counts it with `ADD_RUN_TALLY <tally> [amount]`, usually from a
## trigger (`TriggerData`) on what the player does, or the game's code with
## `RunService.add_tally()` and `raise_tally()`; `RUN_TALLY_AT_LEAST` asks
## about it. The run's report (`RunService.get_last_report()`) lists every
## tally the run raised, and a tally with a `best_flag` keeps the best of any
## run in the player's profile, which a record (`RecordData`) or an
## achievement's progress (`AchievementData.progress_flag`) shows.

const KIND := &"run_tally"

## The name a run's report gives it.
@export var display_name := ""
## Where it stands in a run's report: lower first, then by id.
@export var order := 0
## The profile counter (`GameProfile`) that keeps the best this tally reached
## in any run, raised as the run raises the tally; none keeps no best.
@export var best_flag: StringName

## The tally with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> RunTallyData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as RunTallyData

## The running game's tallies in the order a report lists them.
static func find_all() -> Array[RunTallyData]:
	var result: Array[RunTallyData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	result.sort_custom(ContentEntry.listed_before)
	return result

## What the run going on raised it to.
func get_value() -> int:
	return RunState.get_tally(id)

## The best any run raised it to, from the profile; 0 without a `best_flag`.
func get_best() -> int:
	return GameProfile.get_int(best_flag) if best_flag != &"" else 0

## Its name as the player reads it.
func get_display_name() -> String:
	return TranslationServer.translate(display_name) if not display_name.is_empty() else String(id)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	return problems
