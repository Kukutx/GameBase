class_name NpcRuleProvider
extends NpcAiProvider

## The lines an NPC chats with when no language model answers: written in the
## game, translated and offline. The greeting follows the moment (a birthday,
## a first meeting, a second talk today, a long absence since the last talk of
## any kind, the time of day); a
## topic's answer is one of its `ChatTopicData.rule_replies` whose placeholders
## all have a value now, the same one all day for the same talk.

func get_source() -> StringName:
	return NpcAiService.SOURCE_RULES

func reply(request: NpcAiRequest) -> String:
	return greeting(request.context) if request.topic == null else answer(request.topic, request.context, request.recent.size())

## What the NPC says when the player walks up, by `context` (`NpcContext`).
func greeting(context: Dictionary) -> String:
	var npc: Dictionary = context.get("npc", {})
	var world: Dictionary = context.get("world", {})
	var facts: Dictionary = (context.get("memory", {}) as Dictionary).get("facts", {})
	var today := int(world.get("day", 1))
	if bool(npc.get("birthday_today", false)):
		return tr("It's my birthday today! Thanks for stopping by.")
	# The day of the talk before this one, scripted or chatted
	# (`ConversationService`); none for a first meeting.
	if not facts.has("previous_talk_day"):
		return tr("Hello! I'm {npc}. Nice to meet you.").format({"npc": tr(String(npc.get("name", "")))})
	var last_day := int(facts["previous_talk_day"])
	if last_day == today:
		return tr("Back again? What's on your mind?")
	if today - last_day >= 7:
		return tr("It's been a while! Good to see you.")
	var minute := int(world.get("minute_of_day", 0))
	if minute < 12 * 60:
		return tr("Good morning!")
	if minute < 18 * 60:
		return tr("Good afternoon!")
	return tr("Good evening!")

## One of `topic`'s rule replies whose placeholders `context` fills, picked by
## the NPC, the day and `salt` (how much has been said); a shrug when none is.
func answer(topic: ChatTopicData, context: Dictionary, salt := 0) -> String:
	var values := placeholder_values(context)
	var candidates := PackedStringArray()
	for reply_text: String in topic.rule_replies:
		var translated := tr(reply_text)
		if Array(ChatTopicData.placeholders_of(translated)).all(func(placeholder: String) -> bool: return not String(values.get(placeholder, "")).is_empty()):
			candidates.append(translated.format(values))
	if candidates.is_empty():
		return tr("Hmm, I couldn't say.")
	var npc_id := String((context.get("npc", {}) as Dictionary).get("id", ""))
	var day := int((context.get("world", {}) as Dictionary).get("day", 1))
	return candidates[posmod(("%s|%s|%d|%d" % [npc_id, topic.id, day, salt]).hash(), candidates.size())]

## The value of each of `ChatTopicData.PLACEHOLDERS` in `context`, translated;
## empty when it has none now.
func placeholder_values(context: Dictionary) -> Dictionary:
	var npc: Dictionary = context.get("npc", {})
	var world: Dictionary = context.get("world", {})
	var events: Array = world.get("active_events", [])
	var state: Dictionary = context.get("npc_state", {})
	var values := {
		"npc": String(npc.get("name", "")),
		"role": String(npc.get("role", "")),
		"location": String(world.get("location_name", "")),
		"weather": String(world.get("weather", "")),
		"season": String(world.get("season", "")),
		"activity": String(state.get("activity", "")),
		"event": String((events[0] as Dictionary).get("name", "")) if not events.is_empty() else "",
	}
	for key: String in values:
		values[key] = tr(values[key]) if not String(values[key]).is_empty() else ""
	values["time"] = String(world.get("time_text", ""))
	return values
