class_name AchievementData
extends ContentEntry

## Something the player achieved once, kept by the player's profile
## (`GameProfile`) across every save. Content unlocks one with the action
## `UNLOCK_ACHIEVEMENT <id>`, usually from a trigger (`TriggerData`), and asks
## about one with the condition `ACHIEVEMENT_UNLOCKED <id>`.

const KIND := &"achievement"

@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
## Whether menus hide its name and description until it is unlocked.
@export var hidden := false

## The achievement with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> AchievementData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as AchievementData

## The running game's achievements, sorted by id.
static func find_all() -> Array[AchievementData]:
	var result: Array[AchievementData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	if description.strip_edges().is_empty():
		problems.append("has no description")
	return problems
