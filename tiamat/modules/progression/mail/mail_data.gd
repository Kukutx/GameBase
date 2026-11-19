class_name MailData
extends ContentEntry

const KIND := &"mail"

@export var sender_npc_id: StringName
@export var sender_name: String
@export var subject: String
@export_multiline var body: String
## When the letter arrives, in the `GameQuery` syntax (`DAY_AT_LEAST 2`,
## `QUEST_COMPLETED first_harvest, HEARTS mira 2`); empty means at once. The
## mail service checks it each day and whenever a quest, a friendship or the
## world's state changes.
@export var condition: String = ""
@export var reward_items: Dictionary = {}
@export_range(0, 999999, 1) var reward_money := 0

## The letter with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> MailData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as MailData

## The running game's letters, sorted by id.
static func find_all() -> Array[MailData]:
	var result: Array[MailData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## Whether the letter arrives on `day` (today when below 1).
func is_available(day: int = -1) -> bool:
	return GameRules.check(condition, {"day": WorldClock.day if day < 1 else day})

func get_sender_display_name() -> String:
	if not sender_name.is_empty():
		return sender_name
	var profile := NpcProfileData.find(sender_npc_id)
	return profile.display_name if profile != null else "Unknown"

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if sender_npc_id != &"" and not registry.has_entry(NpcProfileData.KIND, sender_npc_id):
		problems.append("references unknown sender npc '%s'" % sender_npc_id)
	if subject.is_empty() or body.is_empty():
		problems.append("requires subject and body")
	if reward_money < 0:
		problems.append("has negative reward money")
	problems.append_array(ItemData.find_amount_problems(reward_items, registry, "rewards", "reward quantity"))
	return problems
