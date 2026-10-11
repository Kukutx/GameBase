class_name FoodBuffData
extends ContentEntry

const KIND := &"food_buff"

@export var display_name: String
@export_multiline var description: String
@export_range(1, 1440, 1) var duration_minutes := 180
## Multiplier of each stat the buff changes, as stat -> factor. The stats are
## those the modules that read them register (`register_stat()`).
@export var modifiers: Dictionary = {}

## Stats registered with `register_stat()`, as stat -> true.
static var _stats: Dictionary = {}

## The food buff with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> FoodBuffData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as FoodBuffData

## The running game's food buffs, sorted by id.
static func find_all() -> Array[FoodBuffData]:
	var result: Array[FoodBuffData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## Declares that some installed module or the game reads `stat` through
## `BuffState.get_multiplier()`. Called from `GameModule.install()`.
static func register_stat(stat: StringName) -> void:
	_stats[stat] = true

func get_multiplier(stat: StringName) -> float:
	return maxf(float(modifiers.get(String(stat), 1.0)), 0.01)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if duration_minutes <= 0:
		problems.append("has invalid duration")
	for raw_stat: Variant in modifiers:
		var stat := StringName(String(raw_stat))
		var value: Variant = modifiers[raw_stat]
		if not _stats.has(stat):
			problems.append("changes stat '%s', which no installed module or the game reads" % stat)
		elif (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or float(value) <= 0.0:
			problems.append("has non-positive or non-numeric multiplier for '%s'" % stat)
	return problems
