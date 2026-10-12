class_name HeartEventService
extends Node

## Which heart events (`HeartEventData`, an NPC's scripted scene at a number of
## hearts) the player has seen, and which one is due when they talk to an NPC:
## the unseen event that matches the NPC's hearts, the location, the day and the
## time, lowest hearts first.
##
## Each event plays once. `ConversationService` plays a due event in place of the
## NPC's daily lines and marks it seen when its dialogue ends, so a scene that is
## cut off plays again. Seen events live in `WorldState`
## (`heart_event:<id>:seen`), so they are saved with the world, and the NPC also
## remembers each one (`NpcMemory`). `heart_event_triggered` fires when one is
## seen.

signal heart_event_triggered(event_id: StringName, npc_id: StringName)

func get_pending_event(npc_id: StringName) -> HeartEventData:
	var location := WorldLocationData.find_current(get_tree())
	var location_id := location.id if location != null else &""
	var hearts := RelationshipState.get_hearts(npc_id)
	var candidates: Array[HeartEventData] = []
	for event: HeartEventData in HeartEventData.find_all():
		if event == null or is_seen(event.id):
			continue
		if event.matches(npc_id, hearts, location_id, WorldClock.day, WorldClock.minute_of_day):
			candidates.append(event)
	candidates.sort_custom(func(a: HeartEventData, b: HeartEventData) -> bool:
		if a.required_hearts == b.required_hearts:
			return String(a.id) < String(b.id)
		return a.required_hearts < b.required_hearts
	)
	return candidates.front() if not candidates.is_empty() else null

func consume_pending_event(npc_id: StringName) -> HeartEventData:
	var event := get_pending_event(npc_id)
	if event == null:
		return null
	mark_seen(event)
	return event

func mark_seen(event: HeartEventData) -> void:
	if event == null or event.id == &"":
		return
	WorldState.set_value(_seen_key(event.id), true)
	NpcMemory.remember_fact(event.npc_id, StringName("heart_event:%s" % String(event.id)), true)
	heart_event_triggered.emit(event.id, event.npc_id)

func is_seen(event_id: StringName) -> bool:
	return event_id != &"" and WorldState.get_bool(_seen_key(event_id))

func get_seen_event_ids(npc_id: StringName = &"") -> Array[StringName]:
	var result: Array[StringName] = []
	for event: HeartEventData in HeartEventData.find_all():
		if event == null or not is_seen(event.id):
			continue
		if npc_id == &"" or event.npc_id == npc_id:
			result.append(event.id)
	return result

func _seen_key(event_id: StringName) -> StringName:
	return StringName("heart_event:%s:seen" % String(event_id))
