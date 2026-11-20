class_name BoonData
extends ContentEntry

## A boon a run may take: a change to the player that lasts the run. The
## player picks it from a few the run offers (`RunService.offer_boons()`, a
## `BoonAltar`), or content gives it (`TAKE_BOON <boon>`). While the run goes
## on it changes stats (`multipliers` and `bonuses`, of stats an installed
## module or the game reads, `GameStats.register_stat()`), once more for each
## time the run took it, and it acts once each time it is taken (`actions`:
## a heal, coins).

const KIND := &"boon"
## A boon a run may take this many times is taken as often as it is offered.
const UNLIMITED := 99

@export var display_name := ""
@export_multiline var description := ""
## When a run may take it: a `GameRules` query; empty, always.
@export var condition := ""
## How often it is offered against the others: twice the weight, twice as often.
@export_range(1, 100, 1) var weight := 10
## How many times one run may take it; `UNLIMITED`, as often as offered.
@export_range(1, 99, 1) var max_stacks := 1
## Multiplier of each stat the boon changes, as stat -> factor, per time taken.
@export var multipliers: Dictionary[StringName, float] = {}
## Amount added to each stat the boon changes, as stat -> amount, per time taken.
@export var bonuses: Dictionary[StringName, float] = {}
## `GameRules` actions run each time it is taken.
@export var actions: PackedStringArray = PackedStringArray()

## The boon with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> BoonData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as BoonData

## The running game's boons, sorted by id.
static func find_all() -> Array[BoonData]:
	var result: Array[BoonData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## How many times the run going on took it.
func get_stacks() -> int:
	return RunState.get_boon_stacks(id)

## Whether the run may take it now: a run goes on, the run took it fewer than
## `max_stacks` times, and its condition holds.
func can_take() -> bool:
	return RunState.is_active() and get_stacks() < max_stacks and GameRules.check(condition)

## Its name as the player reads it.
func get_display_name() -> String:
	return TranslationServer.translate(display_name) if not display_name.is_empty() else String(id)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	if multipliers.is_empty() and bonuses.is_empty() and actions.is_empty():
		problems.append("changes no stat and has no actions")
	problems.append_array(GameStats.find_change_problems(multipliers, bonuses))
	return problems
