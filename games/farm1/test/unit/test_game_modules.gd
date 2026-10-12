extends GutTest

func test_every_linked_module_and_the_game_installed_itself() -> void:
	assert_eq(GameModules.get_installed(), PackedStringArray([
		"CombatModule", "DamageModule", "GameSetup", "ItemsModule", "LifesimModule", "NpcAiModule", "NpcSocialModule", "ProgressionModule", "SkillsModule",
	]))

func test_each_module_registered_its_kinds_of_content() -> void:
	assert_eq(ContentDB.get_kinds(), [
		&"achievement", &"audio_cue", &"calendar_event", &"chat_topic", &"collection_milestone", &"crop", &"enemy", &"faction", &"farm_animal", &"farm_expansion",
		&"fish", &"food_buff", &"forage_entry", &"heart_event", &"hint", &"item", &"location", &"mail", &"minigame", &"mining_node",
		&"npc", &"placeable", &"processing_recipe", &"quest", &"recipe", &"region", &"shop", &"skill", &"tool_upgrade", &"town_project", &"trigger", &"vital", &"weather",
	])
