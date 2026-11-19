class_name MFarmNpcData
extends ContentEntry

## A townsperson: how they look, where they start, where their day takes them
## (`schedule`, by time of day) and what they say. One with a shop bag sells
## its stock once the conversation ends.

const KIND := &"mfarm_npc"

@export var display_name: String
@export var animations: AnimationLibrary
## The prefix of their clips in `animations`: `<prefix>IdleDown`, `<prefix>WalkLeft`, ...
@export var clip_prefix: String
@export var extra_animations: AnimationLibrary
@export var shadow: Texture2D
@export_range(1.0, 400.0) var walk_speed := 40.0
@export var start_location_id: StringName
@export var start_cell := Vector2i.ZERO
@export var schedule: Array[MFarmScheduleEntry] = []
@export var dialogue: Array[MFarmDialogueLine] = []
## The stock (`MFarmBagData`) they sell, or none.
@export var shop_bag_id: StringName

static func find(entry_id: StringName) -> MFarmNpcData:
	if entry_id == &"" or ContentRegistry.active == null:
		return null
	return ContentRegistry.active.get_entry(KIND, entry_id) as MFarmNpcData

static func find_all() -> Array[MFarmNpcData]:
	var result: Array[MFarmNpcData] = []
	for entry: ContentEntry in ContentRegistry.active.get_entries(KIND):
		result.append(entry as MFarmNpcData)
	return result

## The schedule entry in force at `minute_of_day`: the latest that started,
## or the day's last one before the first starts.
func get_entry_at(minute_of_day: int) -> MFarmScheduleEntry:
	var current: MFarmScheduleEntry = null
	var latest: MFarmScheduleEntry = null
	for entry: MFarmScheduleEntry in schedule:
		if latest == null or entry.get_minute_of_day() > latest.get_minute_of_day():
			latest = entry
		if entry.get_minute_of_day() <= minute_of_day and (current == null or entry.get_minute_of_day() > current.get_minute_of_day()):
			current = entry
	return current if current != null else latest

func get_clip(action: String, direction: String) -> StringName:
	return StringName("%s%s%s" % [clip_prefix, action, direction])

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if animations == null:
		problems.append("has no animations")
	if not registry.has_entry(WorldLocationData.KIND, start_location_id):
		problems.append("starts at unknown location '%s'" % start_location_id)
	for entry: MFarmScheduleEntry in schedule:
		if not registry.has_entry(WorldLocationData.KIND, entry.location_id):
			problems.append("goes to unknown location '%s'" % entry.location_id)
		if entry.stop_animation != &"" and not _has_clip(entry.stop_animation):
			problems.append("plays unknown animation '%s'" % entry.stop_animation)
	if shop_bag_id != &"" and not registry.has_entry(MFarmBagData.KIND, shop_bag_id):
		problems.append("sells unknown stock '%s'" % shop_bag_id)
	return problems

func _has_clip(clip: StringName) -> bool:
	return (animations != null and animations.has_animation(clip)) or (extra_animations != null and extra_animations.has_animation(clip))
