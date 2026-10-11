class_name FoodBuffData
extends ContentEntry

const KIND := &"food_buff"

@export var display_name: String
@export_multiline var description: String
@export_range(1, 1440, 1) var duration_minutes := 180
## Multiplier of each stat the buff changes, as stat -> factor: stats an
## installed module or the game reads (`GameStats.register_stat()`).
@export var multipliers: Dictionary[StringName, float] = {}
## Amount added to each stat the buff changes, as stat -> amount.
@export var bonuses: Dictionary[StringName, float] = {}

## The food buff with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> FoodBuffData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as FoodBuffData

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
