class_name NpcMemoryStore
extends Node

## What each NPC remembers of the player: the latest messages of their
## conversations (up to `max_recent_messages` per NPC, each with its day, time
## and place) and named facts, such as the last day they talked or a heart event
## seen. `NpcContext` puts this memory in what an NPC knows when it talks.
##
## The memory is saved with the game, and a new game starts with none.
## `memory_changed` fires with the NPC whose memory changed, or with an empty id
## when all of it was cleared or loaded.

signal memory_changed(npc_id: StringName)

@export_range(4, 100, 1) var max_recent_messages := 24

var _history: Dictionary = {}
var _facts: Dictionary = {}

func append_message(npc_id: StringName, role: StringName, text: String) -> void:
	if npc_id == &"" or text.strip_edges().is_empty():
		return
	var key := String(npc_id)
	var messages: Array = _history.get(key, [])
	messages.append({
		"role": String(role),
		"text": text.strip_edges(),
		"day": WorldClock.day,
		"minute_of_day": WorldClock.minute_of_day,
		"location_id": String(_current_location_id()),
	})
	while messages.size() > max_recent_messages:
		messages.pop_front()
	_history[key] = messages
	memory_changed.emit(npc_id)

func remember_fact(npc_id: StringName, fact_id: StringName, value: Variant) -> void:
	if npc_id == &"" or fact_id == &"":
		return
	var key := String(npc_id)
	var facts: Dictionary = _facts.get(key, {})
	facts[String(fact_id)] = value
	_facts[key] = facts
	memory_changed.emit(npc_id)

func forget_fact(npc_id: StringName, fact_id: StringName) -> void:
	var key := String(npc_id)
	var facts: Dictionary = _facts.get(key, {})
	if facts.erase(String(fact_id)):
		_facts[key] = facts
		memory_changed.emit(npc_id)

func get_recent_messages(npc_id: StringName, limit: int = -1) -> Array[Dictionary]:
	var source: Array = _history.get(String(npc_id), [])
	var count := source.size() if limit < 0 else mini(source.size(), maxi(limit, 0))
	var result: Array[Dictionary] = []
	var start := maxi(source.size() - count, 0)
	for index in range(start, source.size()):
		var raw: Variant = source[index]
		if raw is Dictionary:
			result.append((raw as Dictionary).duplicate(true))
	return result

func get_facts(npc_id: StringName) -> Dictionary:
	var facts: Variant = _facts.get(String(npc_id), {})
	return (facts as Dictionary).duplicate(true) if facts is Dictionary else {}

func clear_npc(npc_id: StringName) -> void:
	var key := String(npc_id)
	var changed := _history.erase(key)
	changed = _facts.erase(key) or changed
	if changed:
		memory_changed.emit(npc_id)

func clear() -> void:
	_history.clear()
	_facts.clear()
	memory_changed.emit(&"")

func to_save_data() -> Dictionary:
	return {
		"history": _history.duplicate(true),
		"facts": _facts.duplicate(true),
	}

func load_save_data(data: Dictionary) -> void:
	var history: Variant = data.get("history", {})
	var facts: Variant = data.get("facts", {})
	_history = {}
	_facts = {}
	var current_day := maxi(WorldClock.day, 1)
	if history is Dictionary:
		for raw_key: Variant in history.keys():
			var raw_messages: Variant = history[raw_key]
			if not raw_messages is Array:
				continue
			var messages: Array = []
			for raw_message: Variant in raw_messages:
				if not raw_message is Dictionary:
					continue
				var message: Dictionary = (raw_message as Dictionary).duplicate(true)
				var text := String(message.get("text", "")).strip_edges()
				if text.is_empty():
					continue
				message["role"] = String(message.get("role", ""))
				message["text"] = text
				message["day"] = clampi(int(message.get("day", 1)), 1, current_day)
				message["minute_of_day"] = clampi(int(message.get("minute_of_day", 0)), 0, GameClock.MINUTES_PER_DAY - 1)
				message["location_id"] = String(message.get("location_id", ""))
				messages.append(message)
			while messages.size() > max_recent_messages:
				messages.pop_front()
			if not messages.is_empty():
				_history[String(raw_key)] = messages
	if facts is Dictionary:
		for raw_key: Variant in facts.keys():
			var raw_facts: Variant = facts[raw_key]
			if raw_facts is Dictionary:
				_facts[String(raw_key)] = (raw_facts as Dictionary).duplicate(true)
	memory_changed.emit(&"")

func _prune_all() -> void:
	for raw_key: Variant in _history.keys():
		var key := String(raw_key)
		var raw_messages: Variant = _history[key]
		if not raw_messages is Array:
			_history.erase(key)
			continue
		var messages: Array = raw_messages
		while messages.size() > max_recent_messages:
			messages.pop_front()
		_history[key] = messages

func _current_location_id() -> StringName:
	var location := WorldLocationData.find_current(get_tree())
	return location.id if location != null else &""
