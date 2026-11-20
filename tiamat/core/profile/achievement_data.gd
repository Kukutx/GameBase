class_name AchievementData
extends ContentEntry

## Something the player achieved once, kept by the player's profile
## (`GameProfile`) across every save. Content unlocks one with the action
## `UNLOCK_ACHIEVEMENT <id>`, usually from a trigger (`TriggerData`), and asks
## about one with the condition `ACHIEVEMENT_UNLOCKED <id>`. One that counts a
## profile counter (`progress_flag`, `goal`) needs no trigger: the profile
## unlocks it once the counter reaches its goal.

const KIND := &"achievement"

@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
## Whether menus hide its name and description until it is unlocked.
@export var hidden := false
## The profile counter (a `GameProfile` flag that `ADD_PROFILE_FLAG` raises)
## it counts toward `goal`, or none. The profile unlocks it once the counter
## reaches the goal, and the achievements menu shows how far the player is.
@export var progress_flag: StringName
## What `progress_flag` reaches to unlock it.
@export var goal := 0

## The achievement with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> AchievementData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as AchievementData

## The running game's achievements, sorted by id.
static func find_all() -> Array[AchievementData]:
	var result: Array[AchievementData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## Whether it counts a profile counter toward a goal.
func counts_progress() -> bool:
	return progress_flag != &"" and goal > 0

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	if description.strip_edges().is_empty():
		problems.append("has no description")
	if progress_flag != &"" and goal < 1:
		problems.append("counts %s toward no goal" % progress_flag)
	if progress_flag == &"" and goal != 0:
		problems.append("has a goal but no progress flag")
	return problems
