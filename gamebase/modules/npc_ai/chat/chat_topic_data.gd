class_name ChatTopicData
extends ContentEntry

## Something the player can bring up when an NPC chats (`NpcAiChat`): the words
## the player says, which NPCs and when, and what an NPC answers without a
## language model (`NpcRuleProvider`). A chat offers the topics that hold, by
## `order`, then the goodbye.

const KIND := &"chat_topic"
## What `rule_replies` can put in their text: the NPC's name and role, where the
## player is, the weather, the time and season, what the NPC is doing and the
## first event on today.
const PLACEHOLDERS: Array[String] = ["npc", "role", "location", "weather", "time", "season", "activity", "event"]

## What the player says, as the response the player picks.
@export var title: String
## The NPCs that take the topic; none means every NPC that chats.
@export var npc_ids: Array[StringName] = []
## What else must hold for the player to bring it up, in the `GameQuery` syntax
## (`HEARTS_AT_LEAST mira 2`); empty means nothing else.
@export var condition: String = ""
## Where it sits among the topics, the lowest first.
@export var order := 0
## What an NPC may answer without a language model, one of them a day: text
## the player reads, with `{placeholder}`s of `PLACEHOLDERS`. A reply whose
## placeholders have no value at the moment is left out.
@export var rule_replies: PackedStringArray = PackedStringArray()

static var _placeholder: RegEx

## The chat topic with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> ChatTopicData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as ChatTopicData

## The running game's chat topics, sorted by id.
static func find_all() -> Array[ChatTopicData]:
	var result: Array[ChatTopicData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## The topics the player can bring up with `npc_id` now, by `order`.
static func find_open(npc_id: StringName) -> Array[ChatTopicData]:
	var result: Array[ChatTopicData] = []
	for topic: ChatTopicData in find_all():
		if topic.is_open(npc_id):
			result.append(topic)
	result.sort_custom(func(a: ChatTopicData, b: ChatTopicData) -> bool: return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return result

## The placeholder names `text` uses, in order.
static func placeholders_of(text: String) -> PackedStringArray:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{(\\w+)\\}")
	var found := PackedStringArray()
	for result: RegExMatch in _placeholder.search_all(text):
		found.append(result.get_string(1))
	return found

## Problems no single topic can tell: an NPC that chats
## (`NpcProfileData.ai_enabled`) with no topic to bring up.
static func find_chat_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	var topics: Array = registry.get_entries(KIND)
	for profile: NpcProfileData in registry.get_entries(NpcProfileData.KIND):
		if profile.ai_enabled and not topics.any(func(topic: ChatTopicData) -> bool: return topic.npc_ids.is_empty() or topic.npc_ids.has(profile.id)):
			problems.append("NPC '%s' chats but no chat topic is for it." % profile.id)
	return problems

func is_open(npc_id: StringName) -> bool:
	return (npc_ids.is_empty() or npc_ids.has(npc_id)) and GameRules.check(condition, {"npc_id": npc_id})

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if title.strip_edges().is_empty():
		problems.append("has no title")
	if rule_replies.is_empty():
		problems.append("has no rule replies")
	for npc_id: StringName in npc_ids:
		if not registry.has_entry(NpcProfileData.KIND, npc_id):
			problems.append("references unknown npc '%s'" % npc_id)
	for reply: String in rule_replies:
		for placeholder: String in placeholders_of(reply):
			if not PLACEHOLDERS.has(placeholder):
				problems.append("rule reply '%s' has unknown placeholder {%s}" % [reply, placeholder])
	return problems
