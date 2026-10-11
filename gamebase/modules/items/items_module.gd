class_name ItemsModule
extends GameModule

## Wires the items module into the core (see `GameModule`).

func install() -> void:
	for kind_script: Script in [ItemData, FoodBuffData, PlaceableData, RecipeData, ShopData]:
		ContentDB.register_kind(kind_script.KIND, kind_script)
	ItemsRules.register(GameRules)
	GameStats.register_source(BuffState)
	SaveManager.register_section(SaveSection.new(&"buffs", 400,
		BuffState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: BuffState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"inventory", 500,
		InventoryState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: InventoryState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"hotbar", 650,
		Hotbar.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Hotbar.load_save_data(section)))
	GameSession.register_new_game_step(&"inventory", 100, InventoryState.clear)
	GameSession.register_new_game_step(&"hotbar", 450, Hotbar.reset_new_game)
	GameSession.register_new_game_step(&"buffs", 900, BuffState.clear)
	GameSession.register_new_game_step(&"start_items", 1300, _grant_start_items)

## The game's `GameDefinition.start_items`, once the inventory is empty.
func _grant_start_items() -> void:
	var start_items := GameDefinition.current().start_items
	for item_id: StringName in start_items:
		InventoryState.add_item_by_id(item_id, start_items[item_id])
