extends Node

## Wires this game's modules into the foundation.
##
## `gamebase/core` does not know which modules a game enables. This autoload runs
## after every service and tells the core services about the enabled modules:
## which save sections they own, what to rebuild after loading, what blocks saving
## how to reset them for a new game, and which condition and action keys exist. Orders interleave with the core's own
## (`GameSaveManager.SECTION_ORDER_*`, `GameSessionService.NEW_GAME_ORDER_*`).

const MINE_FLOOR_TABLE := preload("res://game/data/mining/mine_floor_table.tres")
# instance id, animal id, location id, housing id, slot index
const START_ANIMALS := [
	[&"starter_chicken_01", &"chicken", &"starter_town", &"starter_coop", 0],
	[&"starter_cow_01", &"cow", &"starter_town", &"starter_barn", 0],
]

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
	MineState.floor_table = MINE_FLOOR_TABLE
	for problem: String in MINE_FLOOR_TABLE.validate(ContentDB):
		push_error("Mine: " + problem)

func _register_save_sections() -> void:
	# Shipping restores its saved day marker before the clock (order 300) emits
	# day_changed, so loading never pays a day twice.
	SaveManager.register_section(SaveSection.new(&"shipping", 200,
		ShippingState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: ShippingState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"buffs", 400,
		BuffState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: BuffState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"inventory", 500,
		InventoryState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: InventoryState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"hotbar", 650,
		Hotbar.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Hotbar.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"relationships", 800,
		RelationshipState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: RelationshipState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"npc_memory", 900,
		NpcMemory.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: NpcMemory.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"quests", 1000,
		QuestState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: QuestState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"skills", 1100,
		Skills.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Skills.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"fishing", 1200,
		FishingState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: FishingState.load_save_data(section)))

func _register_load_steps() -> void:
	# A quest whose reward did not fit when it was saved completes once loaded.
	SaveManager.register_load_step(&"quests", 100, QuestState.complete_ready_quests)
	# EventState keeps which festival is running only at runtime; rebuild it
	# from the restored clock and world flags.
	SaveManager.register_load_step(&"calendar_events", 200,
		func() -> void: EventState.refresh(WorldClock.day, WorldClock.minute_of_day))

func _register_new_game_steps() -> void:
	GameSession.register_new_game_step(&"inventory", 100, InventoryState.clear)
	GameSession.register_new_game_step(&"animals", 300, AnimalState.reset_new_game)
	GameSession.register_new_game_step(&"start_animals", 310, _grant_start_animals)
	GameSession.register_new_game_step(&"hotbar", 450, Hotbar.reset_new_game)
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

func _grant_start_animals() -> void:
	for animal: Array in START_ANIMALS:
		AnimalState.grant_animal(animal[0], animal[1], animal[2], animal[3], animal[4])

func _fishing_save_block_reason() -> String:
	return tr("Finish fishing before saving") if FishingState.is_active() else ""
