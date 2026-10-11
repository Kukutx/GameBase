class_name ForageEntryData
extends ContentEntry

const KIND := &"forage_entry"

@export var item_id: StringName
@export var locations: Array[StringName] = []
@export var seasons: PackedStringArray = PackedStringArray()
@export_range(0.01, 100.0, 0.01) var weight := 1.0
@export_range(1, 99, 1) var min_quantity := 1
@export_range(1, 99, 1) var max_quantity := 1

## The forage entry with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> ForageEntryData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as ForageEntryData

## The running game's forage entries, sorted by id.
static func find_all() -> Array[ForageEntryData]:
	var result: Array[ForageEntryData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func is_available(location_id: StringName, season_name: String) -> bool:
	if not locations.is_empty() and not locations.has(location_id):
		return false
	if not seasons.is_empty() and not seasons.has(season_name):
		return false
	return item_id != &"" and weight > 0.0

func get_quantity(rng: GameRandomStream) -> int:
	var minimum := mini(min_quantity, max_quantity)
	var maximum := maxi(min_quantity, max_quantity)
	return rng.randi_range(minimum, maximum)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not registry.has_entry(ItemData.KIND, item_id):
		problems.append("references unknown item '%s'" % item_id)
	for location_id: StringName in locations:
		if not registry.has_entry(WorldLocationData.KIND, location_id):
			problems.append("references unknown location '%s'" % location_id)
	for season: String in seasons:
		if not GameClock.SEASON_NAMES.has(season):
			problems.append("has unknown season '%s'" % season)
	return problems
