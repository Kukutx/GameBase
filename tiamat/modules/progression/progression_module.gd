class_name ProgressionModule
extends GameModule

## Wires the progression module into the core (see `GameModule`).

func install() -> void:
	for kind_script: Script in [MailData, QuestData, ToolUpgradeData, TownProjectData]:
		ContentDB.register_kind(kind_script.KIND, kind_script)
	ContentDB.register_check(QuestData.find_chain_problems)
	ContentDB.register_check(TownProjectData.find_cycle_problems)
	ProgressionRules.register(GameRules)
	ItemSources.register(&"progression", find_item_sources)
	SaveManager.register_section(SaveSection.new(&"quests", 1000,
		QuestState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: QuestState.load_save_data(section)))
	# A quest whose reward did not fit when it was saved completes once loaded.
	SaveManager.register_load_step(&"quests", 100, QuestState.complete_ready_quests)
	GameSession.register_new_game_step(&"quests_clear", 700, QuestState.load_save_data.bind({}))
	GameSession.register_new_game_step(&"quests_start", 1400, QuestState.reset_new_game)
	# Letters wait while a save restores or a new game is set up; mail state
	# itself lives in WorldState, which both replace.
	GameSession.play_started.connect(MailState.refresh_deliveries)

## The started quests and the town projects.
func get_facts() -> Dictionary:
	return {"quests": QuestState.get_journal_entries(), "town_projects": TownProjects.get_context_entries()}

## The ways to get items the module gives (`ItemSources`): the rewards of a
## quest and of a town project, a letter's gift and a tool's upgrade.
static func find_item_sources(registry: ContentRegistry, sources: ItemSources) -> void:
	for quest: QuestData in registry.get_entries(QuestData.KIND):
		sources.add_each(quest.reward_items, TranslationServer.translate("Reward for %s") % TranslationServer.translate(quest.title))
	for project: TownProjectData in registry.get_entries(TownProjectData.KIND):
		sources.add_each(project.reward_items, TranslationServer.translate("Reward for %s") % TranslationServer.translate(project.display_name))
	for mail: MailData in registry.get_entries(MailData.KIND):
		sources.add_each(mail.reward_items, TranslationServer.translate("Sent by %s") % TranslationServer.translate(mail.get_sender_display_name()))
	for upgrade: ToolUpgradeData in registry.get_entries(ToolUpgradeData.KIND):
		var source := registry.get_entry(ItemData.KIND, upgrade.source_item_id) as ItemData
		var from := String(TranslationServer.translate(source.display_name)) if source != null else String(upgrade.source_item_id)
		sources.add(upgrade.result_item_id, TranslationServer.translate("Upgraded from %s") % from)
