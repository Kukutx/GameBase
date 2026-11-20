class_name RecordData
extends ContentEntry

## A number the player's profile keeps across every save, shown under Records
## in the achievements menu (`AchievementsMenu`): crops harvested, the deepest
## depth reached. It reads a profile counter (`GameProfile`, `flag`) that
## content raises with `ADD_PROFILE_FLAG` (a count) or `RAISE_PROFILE_FLAG` (a
## best), usually from a trigger (`TriggerData`) on what the player does, or
## that the game's code sets.

const KIND := &"record"

@export var display_name := ""
## The profile counter it shows.
@export var flag: StringName
## Where it stands among the records: lower first, then by id.
@export var order := 0

## The record with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> RecordData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as RecordData

## The running game's records in the order they show.
static func find_all() -> Array[RecordData]:
	var result: Array[RecordData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	result.sort_custom(ContentEntry.listed_before)
	return result

## What the record stands at in the player's profile.
func get_value() -> int:
	return GameProfile.get_int(flag)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	if flag == &"":
		problems.append("names no profile flag")
	return problems
