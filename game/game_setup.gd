extends Node

## Wires this game's modules into the foundation.
##
## `gamebase/core` does not know which modules a game enables. This autoload runs
## after every service and tells the core services about the enabled modules:
## which save sections they own, what to repair after loading, what blocks saving
## how to reset them for a new game, and which condition and action keys exist. Orders interleave with the core's own
## (`GameSaveManager.SECTION_ORDER_*`, `GameSessionService.NEW_GAME_ORDER_*`).

func _ready() -> void:
	ItemsRules.register(GameRules)
	ProgressionRules.register(GameRules)
	NpcSocialRules.register(GameRules)
	# Content is indexed before the modules register their rule keys, so the
	# conditions and actions it names are checked here, once every key exists.
	for problem: String in GameRules.validate_content(ContentDB):
		push_error("GameRules: " + problem)
	_register_save_sections()
	_register_load_steps()
	_register_new_game_steps()
	SaveManager.register_save_blocker(_fishing_save_block_reason)
	FishingState.reel_minigame_id = &"fishing_reel"

func _register_save_sections() -> void:
	# Shipping restores its saved day marker before the clock (order 300) emits
	# day_changed, otherwise loading an older or newer save could pay twice.
	SaveManager.register_section(SaveSection.new(&"shipping", 200, 6,
		ShippingState.to_save_data, _read_shipping, true))
	SaveManager.register_section(SaveSection.new(&"buffs", 400, 7,
		BuffState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: BuffState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"inventory", 500, 1,
		InventoryState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: InventoryState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"relationships", 800, 2,
		RelationshipState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: RelationshipState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"npc_memory", 900, 3,
		NpcMemory.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: NpcMemory.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"quests", 1000, 2,
		QuestState.to_save_data, _read_quests, true))
	SaveManager.register_section(SaveSection.new(&"skills", 1100, 2,
		Skills.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Skills.load_save_data(section), true))
	SaveManager.register_section(SaveSection.new(&"fishing", 1200, 4,
		FishingState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: FishingState.load_save_data(section)))

func _read_shipping(section: Dictionary, snapshot: Dictionary) -> void:
	ShippingState.load_save_data(section)
	var clock: Variant = snapshot.get("clock", {})
	if clock is Dictionary:
		var day: Variant = clock.get("day", 1)
		ShippingState.reconcile_loaded_day(int(day) if day is int or day is float else 1)

func _read_quests(section: Dictionary, _snapshot: Dictionary) -> void:
	if not section.is_empty():
		QuestState.load_save_data(section)
	else:
		# Saves from before the quest system (or repaired saves missing the section)
		# must not inherit the currently running session or load into a questless
		# dead-end. Rebuild only the data-declared automatic entry quests.
		QuestState.reset_new_game()

func _register_load_steps() -> void:
	SaveManager.register_load_step(&"quests", 100, QuestState.reconcile_loaded_progress)
	# Town-project completion is derived from contributed materials and can become
	# newly satisfiable after a content update changes requirements. Repair it, and
	# reapply current unlock flags, before mail and event backfill runs.
	SaveManager.register_load_step(&"town_projects", 200, TownProjects.reconcile_loaded_progress)
	# Preserve paid housing capacity independently from expansion resource IDs so
	# future content renames/removals cannot shrink an old save's coop/barn.
	SaveManager.register_load_step(&"farm_expansions", 300, FarmExpansionState.reconcile_loaded_state)
	# Collection readiness is derived from WorldState. Re-evaluate it after loading
	# so newly-ready or legacy-ready milestones freeze their promised rewards
	# before the player can claim them.
	SaveManager.register_load_step(&"collection_milestones", 400, CollectionMilestones.reconcile_loaded_state)
	# WorldClock is restored before WorldState so services can preserve their saved
	# day markers, but calendar flags live inside WorldState. Rebuild them once the
	# world snapshot is in place so an old save loaded during a festival cannot
	# keep EventState active while losing event:<id>:active flags.
	SaveManager.register_load_step(&"calendar_events", 500,
		func() -> void: EventState.refresh(WorldClock.day, WorldClock.minute_of_day, true))
	# Content updates can introduce new letters whose requirements were already
	# satisfied in an older save. Refresh once every prerequisite is restored so
	# those letters arrive on load instead of waiting for the next day.
	SaveManager.register_load_step(&"mail", 600, MailState.refresh_deliveries)

func _register_new_game_steps() -> void:
	GameSession.register_new_game_step(&"inventory", 100, InventoryState.clear)
	GameSession.register_new_game_step(&"animals", 300, AnimalState.reset_new_game)
	GameSession.register_new_game_step(&"relationships", 500, RelationshipState.clear)
	GameSession.register_new_game_step(&"npc_memory", 600, NpcMemory.clear)
	GameSession.register_new_game_step(&"quests_clear", 700, QuestState.load_save_data.bind({}))
	GameSession.register_new_game_step(&"skills", 800, Skills.reset_new_game)
	GameSession.register_new_game_step(&"buffs", 900, BuffState.clear)
	GameSession.register_new_game_step(&"shipping", 1000, ShippingState.reset_new_game)
	GameSession.register_new_game_step(&"fishing", 1100, FishingState.reset_new_game)
	GameSession.register_new_game_step(&"start_items", 1300, _grant_start_items)
	GameSession.register_new_game_step(&"quests_start", 1400, QuestState.reset_new_game)

func _grant_start_items() -> void:
	for item_id: StringName in GameSession.definition.start_items:
		InventoryState.add_item_by_id(item_id, GameSession.definition.start_items[item_id])

func _fishing_save_block_reason() -> String:
	return tr("Finish fishing before saving") if FishingState.is_active() else ""
