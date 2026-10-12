class_name NpcAiModule
extends GameModule

## Wires NPC chats into the core and the npc_social module (see `GameModule`):
## an NPC that chats (`NpcProfileData.ai_enabled`) answers the topics the
## player brings up (`ChatTopicData`) instead of saying its daily lines.

func install() -> void:
	ContentDB.register_kind(ChatTopicData.KIND, ChatTopicData)
	ContentDB.register_settings(NpcAiSettings)
	ContentDB.register_check(ChatTopicData.find_chat_problems)
	ConversationService.chat_maker = make_chat
	GameSession.register_activity_end(NpcAi.cancel_all)
	GameSettings.register_online_service(&"npc_ai", func() -> bool: return NpcAiSettings.current().has_endpoint())

## The chat of `npc` with the player `actor`.
static func make_chat(npc: GameNpc, actor: Node) -> DialogueChat:
	return NpcAiChat.new(npc.get_npc_id(), TranslationServer.translate(npc.display_name), actor)
