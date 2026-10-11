class_name NpcSocialModule
extends GameModule

## Wires the NPC and social module into the core (see `GameModule`).

func install() -> void:
	ContentDB.register_kind(NpcProfileData.KIND, NpcProfileData)
	ContentDB.register_kind(HeartEventData.KIND, HeartEventData)
	NpcSocialRules.register(GameRules)
	SaveManager.register_section(SaveSection.new(&"relationships", 800,
		RelationshipState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: RelationshipState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"npc_memory", 900,
		NpcMemory.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: NpcMemory.load_save_data(section)))
	GameSession.register_new_game_step(&"relationships", 500, RelationshipState.clear)
	GameSession.register_new_game_step(&"npc_memory", 600, NpcMemory.clear)
