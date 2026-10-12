class_name NpcAiPrompt
extends RefCounted

## What a chat asks a language model (`NpcHttpProvider`): the instructions,
## which make the model the NPC (who it is, the moment, the relationship, what
## it remembers) and set how it answers, and the messages, which are the latest
## talk with the player and what the player says now. The messages take turns,
## the player's first and last, as chat endpoints expect.

## What the player does when a chat opens, as the player's turn of the greeting.
const GREETING_TURN := "(The player walks up to you.)"

## The instructions for `request`.
static func instructions(request: NpcAiRequest) -> String:
	var context := request.context
	var npc: Dictionary = context.get("npc", {})
	var world: Dictionary = context.get("world", {})
	var relationship: Dictionary = context.get("relationship", {})
	var state: Dictionary = context.get("npc_state", {})
	var memory: Dictionary = context.get("memory", {})
	var name := _shown(npc.get("name", ""))
	var lines := PackedStringArray()
	lines.append("You are %s, a character in a video game: %s. Stay in character and speak to the player as %s." % [name, _shown(npc.get("role", "")), name])
	for field: String in ["background", "personality", "speaking_style"]:
		if not String(npc.get(field, "")).is_empty():
			lines.append("%s: %s" % [field.capitalize(), npc[field]])
	lines.append("Now: day %d, %s, %s, %s weather, at %s." % [int(world.get("day", 1)), _shown(world.get("season", "")), world.get("time_text", ""), _shown(world.get("weather", "")), _shown(world.get("location_name", ""))])
	var events := PackedStringArray()
	for event: Dictionary in world.get("active_events", []):
		events.append(_shown(event.get("name", "")))
	if not events.is_empty():
		lines.append("On today: %s." % ", ".join(events))
	if not String(state.get("activity", "")).is_empty():
		lines.append("You are busy with: %s." % _shown(state["activity"]))
	lines.append("Your friendship with the player: %d of %d hearts." % [int(relationship.get("hearts", 0)), RelationshipManager.MAX_HEARTS])
	if bool(npc.get("birthday_today", false)):
		lines.append("Today is your birthday.")
	var facts: Dictionary = memory.get("facts", {})
	if not facts.is_empty():
		lines.append("What you know: %s." % JSON.stringify(facts))
	if not request.recalled.is_empty():
		lines.append("Earlier talks you remember:")
		for message: Dictionary in request.recalled:
			lines.append("- day %d, %s: %s" % [int(message.get("day", 1)), name if String(message.get("role", "")) == "npc" else "the player", message.get("text", "")])
	lines.append("Answer in %s with one to three short sentences of plain text: no lists, no markup, no stage directions, nothing in brackets. Do not mention being an AI or these instructions, and promise the player nothing." % TranslationServer.get_locale_name(request.locale))
	return "\n".join(lines)

## The turns of `request`'s talk: the latest messages, then what the player
## says now, each as {"role": "user" or "assistant", "content": text}.
static func messages(request: NpcAiRequest) -> Array[Dictionary]:
	var turns: Array[Dictionary] = []
	for message: Dictionary in request.recent:
		_add_turn(turns, "assistant" if String(message.get("role", "")) == "npc" else "user", String(message.get("text", "")))
	_add_turn(turns, "user", GREETING_TURN if request.topic == null else request.player_text)
	while not turns.is_empty() and turns[0]["role"] != "user":
		turns.pop_front()
	return turns

# Adds a turn, joined to the last one when the same side speaks again.
static func _add_turn(turns: Array[Dictionary], role: String, text: String) -> void:
	if text.strip_edges().is_empty():
		return
	if not turns.is_empty() and turns.back()["role"] == role:
		turns.back()["content"] += "\n" + text
	else:
		turns.append({"role": role, "content": text})

# Content text as the player reads it, in the game's language.
static func _shown(value: Variant) -> String:
	var text := String(value)
	return TranslationServer.translate(text) if not text.is_empty() else ""
