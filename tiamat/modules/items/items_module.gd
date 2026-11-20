class_name ItemsModule
extends GameModule

## Wires the items module into the core (see `GameModule`).

func install() -> void:
	for kind_script: Script in [ItemData, FoodBuffData, PlaceableData, RecipeData, ShopData, StatUpgradeData]:
		ContentDB.register_kind(kind_script.KIND, kind_script)
	ContentDB.register_settings(ItemsSettings)
	ItemsRules.register(GameRules)
	ItemSources.register(&"items", find_item_sources)
	PauseMenu.add_page(&"items", "Items", 10, describe_carried)
	GameStats.register_source(BuffState)
	BuffState.buffs_changed.connect(GameStats.notify_changed)
	GameStats.register_source(StatUpgrades.instance())
	SaveManager.register_section(SaveSection.new(&"buffs", 400,
		BuffState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: BuffState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"inventory", 500,
		InventoryState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: InventoryState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(WalletService.SAVE_SECTION, 550,
		Wallet.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Wallet.load_save_data(section)))
	SaveManager.register_slot_detail(&"money", 10, Wallet.describe_save)
	SaveManager.register_section(SaveSection.new(&"hotbar", 650,
		Hotbar.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: Hotbar.load_save_data(section)))
	GameSession.register_new_game_step(&"inventory", 100, InventoryState.clear)
	GameSession.register_new_game_step(&"wallet", 420, Wallet.reset_new_game)
	GameSession.register_new_game_step(&"hotbar", 450, Hotbar.reset_new_game)
	GameSession.register_new_game_step(&"buffs", 900, BuffState.clear)
	GameSession.register_new_game_step(&"start_items", 1300, _grant_start_items)

## What the player carries: their money, the item selected in the hotbar and
## every stack in the inventory.
func get_facts() -> Dictionary:
	return {"inventory": {
		"money": Wallet.money,
		"selected_item_id": String(Hotbar.get_selected_item_id()),
		"items": InventoryState.get_entries(),
	}}

## What the player carries, for the pause menu's Items: their money, then a
## line per stack ("Wild Berry x3") with what it is, what it does
## (`ItemData.describe_effects()`) and where to get more under it; nothing
## while they carry nothing.
static func describe_carried() -> PackedStringArray:
	var lines := PackedStringArray()
	var entries := InventoryState.get_entries()
	if entries.is_empty():
		return lines
	lines.append(TranslationServer.translate("Money: %s") % Wallet.describe())
	var sources := ItemSources.gather()
	for entry: Dictionary in entries:
		var item := ItemData.find(StringName(String(entry["id"])))
		if item == null:
			continue
		lines.append("%s x%d" % [TranslationServer.translate(item.display_name), int(entry["quantity"])])
		if not item.description.is_empty():
			lines.append("  " + TranslationServer.translate(item.description))
		var effects := item.describe_effects()
		if not effects.is_empty():
			lines.append("  " + ItemData.EFFECT_SEPARATOR.join(effects))
		var ways := sources.get_ways(item.id)
		if not ways.is_empty():
			lines.append("  " + TranslationServer.translate("Where to get: %s") % "; ".join(ways))
	return lines

## The ways to get items the module gives (`ItemSources`): a shop's stock, a
## recipe's dish or craft, the items the player starts with and those the
## actions of content add (a trigger's, a quest's).
static func find_item_sources(registry: ContentRegistry, sources: ItemSources) -> void:
	for shop: ShopData in registry.get_entries(ShopData.KIND):
		var sold_at: String = TranslationServer.translate("Sold at %s") % TranslationServer.translate(shop.display_name)
		sources.add_each(shop.stock, sold_at)
		for season: Variant in shop.seasonal_stock:
			if shop.seasonal_stock[season] is Dictionary:
				sources.add_each(shop.seasonal_stock[season], sold_at)
	for recipe: RecipeData in registry.get_entries(RecipeData.KIND):
		var made: String = TranslationServer.translate("Cooked from %s") if recipe.category == RecipeData.Category.COOKING else TranslationServer.translate("Crafted from %s")
		sources.add(recipe.output_item_id, made % ItemSources.describe_amounts(registry, recipe.ingredients))
	sources.add_each(ItemsSettings.current().start_items, TranslationServer.translate("Carried from the start"))
	for args: PackedStringArray in GameQuery.find_action_args(registry, &"ADD_ITEM"):
		if not args.is_empty():
			sources.add(StringName(args[0]), TranslationServer.translate("Given as a reward"))

## The game's `ItemsSettings.start_items`, once the inventory is empty.
func _grant_start_items() -> void:
	var start_items := ItemsSettings.current().start_items
	for item_id: StringName in start_items:
		InventoryState.add_item_by_id(item_id, start_items[item_id])
