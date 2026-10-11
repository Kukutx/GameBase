class_name MailData
extends ContentEntry

const KIND := &"mail"

@export var sender_npc_id: StringName
@export var sender_name: String
@export var subject: String
@export_multiline var body: String
@export_range(1, 9999, 1) var available_from_day := 1
@export var required_completed_quest_id: StringName
@export var required_world_flag: StringName
@export var required_world_flag_value := true
@export_range(0, 10, 1) var required_hearts := 0
## Extra availability check in the `GameQuery` syntax, e.g. `HAS_ITEM berry 3`;
## empty means no extra check.
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

func is_available(day: int = -1) -> bool:
	var resolved_day := WorldClock.day if day < 1 else day
	if resolved_day < available_from_day:
		return false
	if required_completed_quest_id != &"" and not QuestState.is_completed(required_completed_quest_id):
		return false
	if required_world_flag != &"" and WorldState.get_bool(required_world_flag) != required_world_flag_value:
		return false
	if required_hearts > 0:
		if sender_npc_id == &"" or RelationshipState.get_hearts(sender_npc_id) < required_hearts:
			return false
	if not condition.is_empty() and not GameRules.check(condition, {"day": resolved_day}):
		return false
	return true

func get_sender_display_name() -> String:
	if not sender_name.is_empty():
		return sender_name
	var profile := NpcProfileData.find(sender_npc_id)
	return profile.display_name if profile != null else "Unknown"

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if sender_npc_id != &"" and not registry.has_entry(NpcProfileData.KIND, sender_npc_id):
		problems.append("references unknown sender npc '%s'" % sender_npc_id)
	if required_hearts > 0 and sender_npc_id == &"":
		problems.append("requires hearts but has no sender npc")
	if subject.is_empty() or body.is_empty():
		problems.append("requires subject and body")
	if available_from_day < 1:
		problems.append("has invalid available day %d" % available_from_day)
	if required_hearts < 0 or required_hearts > RelationshipManager.MAX_HEARTS:
		problems.append("has invalid heart requirement %d" % required_hearts)
	if reward_money < 0:
		problems.append("has negative reward money")
	if required_completed_quest_id != &"" and not registry.has_entry(QuestData.KIND, required_completed_quest_id):
		problems.append("references unknown required quest '%s'" % required_completed_quest_id)
	problems.append_array(ItemData.find_amount_problems(reward_items, registry, "rewards", "reward quantity"))
	return problems
