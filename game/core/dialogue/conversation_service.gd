class_name GameConversationService
extends Node

signal conversation_requested(npc_id: StringName, actor: Node)
signal context_prepared(npc_id: StringName, context: Dictionary)

var ai_provider: Node
var prefer_ai := false
var _starting := false
var _active_balloon: Node
var _active_balloon_id := 0
var _active_heart_event: HeartEventData
var _active_heart_dialogue: DialogueResource

func start_conversation(npc: GameNpc, actor: Node, dialogue: DialogueResource, title: String = "start") -> void:
	if npc == null or _starting:
		return
	_starting = true
	_start_conversation_internal(npc, actor, dialogue, title)
	_starting = false

func _start_conversation_internal(npc: GameNpc, actor: Node, dialogue: DialogueResource, title: String) -> void:
	if npc == null:
		return
	var npc_id := npc.get_npc_id()
	conversation_requested.emit(npc_id, actor)
	NpcMemory.remember_fact(npc_id, &"last_talk_day", WorldClock.day)
	NpcMemory.remember_fact(npc_id, &"last_relationship_points", RelationshipState.get_points(npc_id))
	var context := NpcContext.build_context(npc_id, actor)
	context_prepared.emit(npc_id, context)

	# Authored heart events are one-shot progression content and always take
	# priority over optional AI chatter. The event is only marked seen after a
	# valid scripted balloon has actually been created.
	var heart_event := HeartEvents.get_pending_event(npc_id)
	if _can_use_ai(npc.profile, heart_event):
		ai_provider.call("start_conversation", npc, actor, context)
		return
	if dialogue == null:
		GameEvents.toastf("%s has nothing to say yet", [npc.display_name])
		return

	var resolved_title := title
	if heart_event != null:
		resolved_title = heart_event.dialogue_title
		if not _dialogue_has_key(dialogue, resolved_title):
			push_warning("Heart event %s references missing dialogue title '%s'" % [String(heart_event.id), resolved_title])
			GameEvents.toast("This heart event dialogue is unavailable")
			return
	else:
		resolved_title = _resolve_daily_title(dialogue, npc.profile, title, RelationshipState.get_hearts(npc_id))
		if not _dialogue_has_key(dialogue, resolved_title):
			GameEvents.toastf("%s has nothing to say yet", [npc.display_name])
			return

	if is_instance_valid(_active_balloon):
		GameEvents.toast("Finish the current conversation first")
		return
	var manager := get_node_or_null("/root/DialogueManager")
	if manager == null or not manager.has_method("show_example_dialogue_balloon"):
		return
	var ended_callback := Callable(self, "_on_dialogue_ended")
	if manager.has_signal("dialogue_ended") and not manager.is_connected("dialogue_ended", ended_callback):
		manager.connect("dialogue_ended", ended_callback)
	var balloon: Variant = manager.call("show_example_dialogue_balloon", dialogue, resolved_title, [actor, npc])
	if balloon == null or not is_instance_valid(balloon):
		return
	_active_balloon = balloon as Node
	_active_balloon_id = _active_balloon.get_instance_id()
	_active_balloon.tree_exited.connect(Callable(self, "_on_scripted_balloon_exited").bind(_active_balloon_id), CONNECT_ONE_SHOT)
	if heart_event != null:
		_active_heart_event = heart_event
		_active_heart_dialogue = dialogue

func _on_dialogue_ended(resource: DialogueResource) -> void:
	if _active_heart_event == null or resource != _active_heart_dialogue:
		return
	var completed_event := _active_heart_event
	_active_heart_event = null
	_active_heart_dialogue = null
	HeartEvents.mark_seen(completed_event)

func _on_scripted_balloon_exited(balloon_id: int) -> void:
	if _active_balloon_id != balloon_id:
		return
	_active_balloon = null
	_active_balloon_id = 0
	# If dialogue_ended did not fire first, the balloon was interrupted. Leave the
	# heart event unseen so the player can trigger the authored scene again.
	_active_heart_event = null
	_active_heart_dialogue = null

func _can_use_ai(profile: NpcProfileData, heart_event: HeartEventData) -> bool:
	return heart_event == null and prefer_ai and profile != null and profile.ai_enabled and ai_provider != null and ai_provider.has_method("start_conversation")

func _resolve_daily_title(dialogue: DialogueResource, profile: NpcProfileData, base_title: String, hearts: int) -> String:
	var preferred := profile.get_dialogue_title(base_title, hearts) if profile != null else base_title
	if _dialogue_has_key(dialogue, preferred):
		return preferred
	if preferred != base_title and _dialogue_has_key(dialogue, base_title):
		return base_title
	return "" if _dialogue_has_key(dialogue, "") else preferred

func _dialogue_has_key(dialogue: DialogueResource, key: String) -> bool:
	if dialogue == null:
		return false
	if key.is_empty():
		return not dialogue.first_title.is_empty() or not dialogue.lines.is_empty()
	return dialogue.titles.has(key) or dialogue.lines.has(key)

func build_context(npc_id: StringName, actor: Node = null) -> Dictionary:
	return NpcContext.build_context(npc_id, actor)

func record_player_message(npc_id: StringName, text: String) -> void:
	NpcMemory.append_message(npc_id, &"player", text)

func record_npc_message(npc_id: StringName, text: String) -> void:
	NpcMemory.append_message(npc_id, &"npc", text)
