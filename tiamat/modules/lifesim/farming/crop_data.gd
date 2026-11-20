class_name CropData
extends ContentEntry

## What a seed grows into on a farm plot (`FarmPlot`, `ItemData.crop_id`): it
## matures in `days_to_mature` watered days in its seasons, gives its harvest
## item, and with `regrow_days` grows again after a harvest.

const KIND := &"crop"

## The name the player reads.
@export var display_name: String
## How many watered days in its seasons it takes to be ready.
@export_range(1, 60, 1) var days_to_mature := 4
## How many days after a harvest it is ready again; 0, a harvest ends it.
@export_range(0, 60, 1) var regrow_days := 0
## The item (`ItemData`, a `CROP`) a harvest gives.
@export var harvest_item_id: StringName
## How many of it a harvest gives.
@export_range(1, 99, 1) var harvest_quantity := 1
## Seasons of the game's calendar it grows in; empty: every season.
@export var allowed_seasons: PackedStringArray = PackedStringArray()
## The colours of the plant as it sprouts and once it is ready; it shades
## from one to the other as it grows.
@export var sprout_color := Color(0.36, 0.68, 0.28, 1.0)
@export var mature_color := Color(0.52, 0.78, 0.32, 1.0)

## The crop with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> CropData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as CropData

## The running game's crops, sorted by id.
static func find_all() -> Array[CropData]:
	var result: Array[CropData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func can_grow_in(season_name: String) -> bool:
	return allowed_seasons.is_empty() or allowed_seasons.has(season_name)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	var harvest := registry.get_entry(ItemData.KIND, harvest_item_id) as ItemData
	if harvest == null:
		problems.append("references unknown harvest item '%s'" % harvest_item_id)
	elif harvest.kind != ItemData.Kind.CROP:
		problems.append("harvest item '%s' is not a CROP item" % harvest_item_id)
	for season: String in allowed_seasons:
		if not GameCalendar.current().has_season(season):
			problems.append("has unknown season '%s'" % season)
	return problems

## The seed items whose crop is no crop of `registry`: items know which crop a
## seed grows (`ItemData.crop_id`) but not crops. Registered by the lifesim
## module as a content check.
static func find_seed_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for item: ItemData in registry.get_entries(ItemData.KIND):
		if item.kind == ItemData.Kind.SEED and not registry.has_entry(KIND, item.crop_id):
			problems.append("item '%s' is a seed of unknown crop '%s'" % [item.id, item.crop_id])
	return problems
