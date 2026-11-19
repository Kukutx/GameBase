class_name GameConversationService
extends Node

## Starts a conversation with an NPC: it notes the talk in the NPC's memory
## (`NpcMemory`), builds what the NPC knows (`NpcContext`) and shows the dialogue
## (`Dialogue`): a due heart event (`HeartEvents`) first, else, for an NPC that
## chats (`NpcProfileData.ai_enabled`) in a game with a module that makes chats
## (`chat_maker`: npc_ai), its chat, else the NPC's lines for its hearts. A heart
## event counts as seen once its dialogue was read to the end. The service
## saves nothing of its own.

signal conversation_requested(npc_id: StringName, actor: Node)
signal context_prepared(npc_id: StringName, context: Dictionary)

## Makes the chat of an NPC that chats, in place of its lines: Callable(npc:
## GameNpc, actor: Node) -> DialogueChat, null to leave the NPC to its lines. A
## module that makes chats sets it (npc_ai); empty: NPCs say their lines.
var chat_maker: Callable
var _starting := false
var _heart_event: HeartEventData
var _heart_dialogue: DialogueResource

func _ready() -> void:
	Dialogue.finished.connect(_on_dialogue_finished)

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
	# The talk before this one, which a chat greets by (`previous_talk_day`).
	var facts := NpcMemory.get_facts(npc_id)
	if facts.has("last_talk_day"):
		NpcMemory.remember_fact(npc_id, &"previous_talk_day", facts["last_talk_day"])
	NpcMemory.remember_fact(npc_id, &"last_talk_day", WorldClock.day)
	NpcMemory.remember_fact(npc_id, &"last_relationship_points", RelationshipState.get_points(npc_id))
	var context := NpcContext.build_context(npc_id, actor)
	context_prepared.emit(npc_id, context)

	# Authored heart events are one-shot progression content and always take
	# priority over optional AI chatter.
	var heart_event := HeartEvents.get_pending_event(npc_id)
	if heart_event == null and chats(npc.profile):
		var chat := chat_maker.call(npc, actor) as DialogueChat
		if chat != null:
			Dialogue.show_chat(chat)
			return
	if dialogue == null:
		GameEvents.toastf("%s has nothing to say yet", [npc.display_name])
		return

	var resolved_title := title
	if heart_event != null:
		resolved_title = heart_event.dialogue_title
		if not DialogueService.has_title(dialogue, resolved_title):
			push_warning("Heart event %s references missing dialogue title '%s'" % [String(heart_event.id), resolved_title])
			GameEvents.toast("This heart event dialogue is unavailable")
			return
	else:
		resolved_title = _resolve_daily_title(dialogue, npc.profile, title, RelationshipState.get_hearts(npc_id))
		if not DialogueService.has_title(dialogue, resolved_title):
			GameEvents.toastf("%s has nothing to say yet", [npc.display_name])
			return

	if heart_event == null:
		Dialogue.show_dialogue(dialogue, resolved_title, [actor, npc])
		return
	# Known before the dialogue starts, as one whose title shows no line ends
	# within `show_dialogue()`; a conversation that shows already refuses it and
	# keeps its own.
	var refused := Dialogue.is_showing()
	if not refused:
		_heart_event = heart_event
		_heart_dialogue = dialogue
	var balloon := Dialogue.show_dialogue(dialogue, resolved_title, [actor, npc])
	if balloon == null and not refused:
		_forget_heart_event()
	elif balloon != null and _heart_event == heart_event:
		balloon.tree_exited.connect(_forget_heart_event, CONNECT_ONE_SHOT)

func _on_dialogue_finished(resource: DialogueResource) -> void:
	if _heart_event == null or resource != _heart_dialogue:
		return
	var event := _heart_event
	_forget_heart_event()
	HeartEvents.mark_seen(event)

# A heart event's balloon that goes before its dialogue ends (a load, the
# title) leaves the event unseen, so the player can play it again.
func _forget_heart_event() -> void:
	_heart_event = null
	_heart_dialogue = null

## Whether the NPC with `profile` chats rather than says its lines: it allows
## it and a module makes chats.
func chats(profile: NpcProfileData) -> bool:
	return profile != null and profile.ai_enabled and chat_maker.is_valid()

func _resolve_daily_title(dialogue: DialogueResource, profile: NpcProfileData, base_title: String, hearts: int) -> String:
	var preferred := profile.get_dialogue_title(base_title, hearts) if profile != null else base_title
	if DialogueService.has_title(dialogue, preferred):
		return preferred
	if preferred != base_title and DialogueService.has_title(dialogue, base_title):
		return base_title
	return "" if DialogueService.has_title(dialogue, "") else preferred

func build_context(npc_id: StringName, actor: Node = null) -> Dictionary:
	return NpcContext.build_context(npc_id, actor)

func record_player_message(npc_id: StringName, text: String) -> void:
	NpcMemory.append_message(npc_id, &"player", text)

func record_npc_message(npc_id: StringName, text: String) -> void:
	NpcMemory.append_message(npc_id, &"npc", text)
