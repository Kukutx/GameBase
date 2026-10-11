class_name ProgressionModule
extends GameModule

## Wires the progression module into the core (see `GameModule`).

func install() -> void:
	ProgressionRules.register(GameRules)
	SaveManager.register_section(SaveSection.new(&"quests", 1000,
		QuestState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: QuestState.load_save_data(section)))
	# A quest whose reward did not fit when it was saved completes once loaded.
	SaveManager.register_load_step(&"quests", 100, QuestState.complete_ready_quests)
	GameSession.register_new_game_step(&"quests_clear", 700, QuestState.load_save_data.bind({}))
	GameSession.register_new_game_step(&"quests_start", 1400, QuestState.reset_new_game)
	NpcContext.register_section(&"quests", func(_npc_id: StringName) -> Variant: return QuestState.get_journal_entries())
	NpcContext.register_section(&"town_projects", func(_npc_id: StringName) -> Variant: return TownProjects.get_context_entries())
