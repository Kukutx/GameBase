class_name QuestData
extends ContentEntry

## A quest: what it asks of the player (`objectives`, each counted from an
## event of any module), what it gives when every objective is met, and the
## quest it leads to. `QuestState` runs them.

const KIND := &"quest"

@export var title: String
@export_multiline var description: String
@export_group("Start")
@export var entry_point := false
@export var auto_start := false
@export_group("Objectives")
## What the quest asks, all of which must be met; at least one.
@export var objectives: Array[QuestObjective] = []
@export_group("Reward")
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Dictionary = {}
@export var next_quest_id: StringName

## The quest with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> QuestData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as QuestData

## The running game's quests, sorted by id.
static func find_all() -> Array[QuestData]:
	var result: Array[QuestData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if title.is_empty():
		problems.append("has an empty title")
	if objectives.is_empty():
		problems.append("has no objectives")
	for index: int in objectives.size():
		var objective := objectives[index]
		if objective == null:
			problems.append("has an empty objective %d" % (index + 1))
			continue
		if objectives.size() > 1 and objective.description.is_empty():
			problems.append("objective %d has no description; each of several objectives says what it asks" % (index + 1))
		for problem: String in objective.find_problems(registry):
			problems.append("objective %d %s" % [index + 1, problem])
	if reward_money < 0:
		problems.append("has negative reward money")
	problems.append_array(ItemData.find_amount_problems(reward_items, registry, "rewards", "reward quantity"))
	if next_quest_id != &"" and not registry.has_entry(KIND, next_quest_id):
		problems.append("references unknown next quest '%s'" % next_quest_id)
	if auto_start and not entry_point:
		problems.append("auto-starts but is not marked as an entry point")
	return problems

## Problems of the quest chain of `registry`: cycles of `next_quest_id`, and
## quests no entry point leads to. Registered by the progression module as a
## content check.
static func find_chain_problems(registry: ContentRegistry) -> PackedStringArray:
	var graph: Dictionary = {}
	var entry_points: Array[String] = []
	for quest: QuestData in registry.get_entries(KIND):
		graph[String(quest.id)] = [String(quest.next_quest_id)] if quest.next_quest_id != &"" else []
		if quest.entry_point:
			entry_points.append(String(quest.id))
	var problems := ContentRegistry.find_dependency_cycles(graph, "quest")
	if graph.is_empty():
		return problems
	if entry_points.is_empty():
		problems.append("quest graph has no entry points")
		return problems
	var reachable: Dictionary = {}
	var pending := entry_points.duplicate()
	while not pending.is_empty():
		var quest_id: String = pending.pop_back()
		if reachable.has(quest_id):
			continue
		reachable[quest_id] = true
		for next_id: String in graph[quest_id]:
			if graph.has(next_id):
				pending.append(next_id)
	var quest_ids: Array = graph.keys()
	quest_ids.sort()
	for quest_id: String in quest_ids:
		if not reachable.has(quest_id):
			problems.append("quest '%s' is unreachable from any entry point" % quest_id)
	return problems
