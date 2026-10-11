class_name GameNpcCatalog
extends Node

func get_profile(npc_id: StringName) -> NpcProfileData:
	return ContentDB.get_npc(npc_id)

func get_all_profiles() -> Array[NpcProfileData]:
	return ContentDB.get_all_npcs()
