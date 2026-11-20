class_name HeartEventData
extends ContentEntry

## An NPC's scripted scene the player sees once (`HeartEventService`): it
## plays in place of the NPC's daily lines when the player talks to them with
## at least `required_hearts` of friendship, at its location, in its seasons
## and hours, once its condition holds; its dialogue is `dialogue_title` of the
## NPC's dialogue.

const KIND := &"heart_event"

## The NPC (`NpcProfileData`) whose scene it is.
@export var npc_id: StringName
## The hearts of friendship with them it takes.
@export_range(0, 10, 1) var required_hearts := 2
## The title, in the NPC's dialogue, of the scene it plays.
@export var dialogue_title: String = "heart_event"
## The location (`WorldLocationData`) it plays in; empty, any.
@export var location_id: StringName
## The seasons of the game's calendar it plays in; empty, every season.
@export var seasons: PackedStringArray = PackedStringArray()
## When in the day it plays, in minutes after midnight.
@export_range(0, 1439, 1) var start_minute := 0
@export_range(1, 1440, 1) var end_minute := 1440
## What else must hold for the event to play, in the `GameQuery` syntax
## (`PROJECT_COMPLETED garden_fund`); empty means nothing else.
@export var condition: String = ""

## The heart event with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> HeartEventData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as HeartEventData

## The running game's heart events, sorted by id.
static func find_all() -> Array[HeartEventData]:
	var result: Array[HeartEventData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func matches(target_npc_id: StringName, hearts: int, target_location_id: StringName, day: int, minute_of_day: int) -> bool:
	if id == &"" or npc_id == &"" or target_npc_id != npc_id:
		return false
	if hearts < required_hearts:
		return false
	if location_id != &"" and target_location_id != location_id:
		return false
	if not seasons.is_empty() and not seasons.has(GameCalendar.current().get_season_name(day)):
		return false
	if minute_of_day < start_minute or minute_of_day >= end_minute:
		return false
	return GameRules.check(condition, {"day": day, "minute_of_day": minute_of_day, "location_id": target_location_id})

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not registry.has_entry(NpcProfileData.KIND, npc_id):
		problems.append("references unknown npc '%s'" % npc_id)
	if location_id != &"" and not registry.has_entry(WorldLocationData.KIND, location_id):
		problems.append("references unknown location '%s'" % location_id)
	if dialogue_title.is_empty():
		problems.append("has an empty dialogue title")
	if required_hearts < 0 or required_hearts > RelationshipManager.MAX_HEARTS:
		problems.append("has invalid heart requirement %d" % required_hearts)
	if end_minute <= start_minute:
		problems.append("has an invalid time window")
	for season: String in seasons:
		if not GameCalendar.current().has_season(season):
			problems.append("has unknown season '%s'" % season)
	return problems
