class_name FoodBuffData
extends ContentEntry

## What eating a food or drinking a potion does to the player's stats for a
## while besides what it restores (`ItemData.food_buff_id`): it changes stats
## of `GameStats` by `multipliers` and `bonuses` for `duration_minutes` of the
## game's clock (`BuffService`). Several may hold at once, and one eaten again
## while it holds starts its time again rather than adding to it.

const KIND := &"food_buff"

## The name the player reads while it holds.
@export var display_name: String
## What the player reads of it.
@export_multiline var description: String
## How long it holds, in minutes of the game's clock.
@export_range(1, 1440, 1) var duration_minutes := 180
## Multiplier of each stat the buff changes, as stat -> factor: stats an
## installed module or the game reads (`GameStats.register_stat()`).
@export var multipliers: Dictionary[StringName, float] = {}
## Amount added to each stat the buff changes, as stat -> amount.
@export var bonuses: Dictionary[StringName, float] = {}

## The food buff with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> FoodBuffData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as FoodBuffData

## What the buff changes as the player reads it (`GameStats.describe_changes()`:
## "Move speed +10%, Max energy +20"); "" when it changes no named stat.
func describe_changes() -> String:
	return GameText.list(GameStats.describe_changes(multipliers, bonuses))

## The running game's food buffs, sorted by id.
static func find_all() -> Array[FoodBuffData]:
	var result: Array[FoodBuffData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if duration_minutes <= 0:
		problems.append("has invalid duration")
	problems.append_array(GameStats.find_change_problems(multipliers, bonuses))
	return problems
