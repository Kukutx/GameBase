class_name NpcAiChat
extends NpcChat

## A chat with an NPC (`NpcAi`): its greeting, then, for each topic the player
## brings up (`ChatTopicData.find_open()`), what the player says and the NPC's
## answer, both kept in the NPC's memory (`ConversationService`), until the
## player says goodbye. The module makes one for each conversation with an NPC
## that chats (`ConversationService.chat_maker`); a chat the balloon drops
## gives up the line it waits for.

var _npc_id: StringName
var _speaker: String
var _actor: Node
var _pending: NpcAiRequest

func _init(npc_id: StringName, speaker: String, actor: Node = null) -> void:
	_npc_id = npc_id
	_speaker = speaker
	_actor = actor

func get_line(id: String) -> DialogueLine:
	if id == END:
		return null
	var topic: ChatTopicData = null
	if id != FIRST:
		topic = ChatTopicData.find(StringName(id))
		if topic == null:
			return null
	var request := NpcAi.make_request(_npc_id, topic, _actor if is_instance_valid(_actor) else null)
	if topic != null:
		ConversationService.record_player_message(_npc_id, request.player_text)
	_pending = request
	NpcAi.submit(request)
	var text := await request.wait()
	_pending = null
	ConversationService.record_npc_message(_npc_id, text)
	var responses: Array[Dictionary] = []
	for open: ChatTopicData in ChatTopicData.find_open(_npc_id):
		responses.append({"next_id": String(open.id), "text": tr(open.title)})
	responses.append({"next_id": END, "text": tr("Goodbye")})
	return make_line("chat:%s:%s" % [_npc_id, id], _speaker, text, responses)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _pending != null:
		_pending.cancel()
