class_name LifesimModule
extends GameModule

## Wires the life-sim module into the core (see `GameModule`).

func install() -> void:
	for kind_script: Script in [CalendarEventData, CollectionMilestoneData, CropData, FarmAnimalData, FarmExpansionData,
			FishData, ForageEntryData, MiningNodeData, ProcessingRecipeData]:
		ContentDB.register_kind(kind_script.KIND, kind_script)
	ContentDB.register_settings(LifesimSettings)
	ContentDB.register_check(CropData.find_seed_problems)
	ContentDB.register_check(FarmExpansionData.find_cycle_problems)
	ContentDB.register_check(CollectionMilestoneData.find_cycle_problems)
	ContentDB.register_check(_find_slot_problems)
	LifesimRules.register(GameRules)
	ItemSources.register(&"lifesim", find_item_sources)
	for action: StringName in [FarmPlot.TILL_ACTION, FarmPlot.WATER_ACTION, MiningNode.TOOL_ACTION, FishingSpot.TOOL_ACTION]:
		ItemData.register_tool_action(action)
	GameStats.register_stat(&"tool_energy", "Tool energy cost")
	GameStats.register_stat(&"farming_energy", "Farming energy cost")
	GameStats.register_stat(&"mining_energy", "Mining energy cost")
	GameStats.register_stat(&"fishing_wait", "Bite wait")
	GameStats.register_stat(&"fishing_window", "Reel window")
	GameStats.register_stat(&"forage_quantity", "Forage found")
	GameStats.register_stat(LifesimSettings.MAX_ENERGY_STAT, "Max energy")
	# Shipping restores its saved day marker before the clock (order 300) emits
	# day_changed, so loading never pays a day twice.
	SaveManager.register_section(SaveSection.new(&"shipping", 200,
		ShippingState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: ShippingState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"fishing_state", 1200,
		FishingState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: FishingState.load_save_data(section)))
	# EventState keeps which festival is running only at runtime; rebuild it
	# from the restored clock.
	SaveManager.register_load_step(&"calendar_events", 200,
		func() -> void: EventState.refresh(WorldClock.day, WorldClock.minute_of_day))
	SaveManager.register_save_blocker(_fishing_save_block_reason)
	GameSession.register_activity_end(FishingState.cancel_cast.bind(false))
	GameSession.register_new_game_step(&"animals", 300, AnimalState.reset_new_game)
	GameSession.register_new_game_step(&"shipping", 1000, ShippingState.reset_new_game)
	GameSession.register_new_game_step(&"fishing_state", 1100, FishingState.reset_new_game)

## The calendar events under way where the player is, or everywhere.
func get_facts() -> Dictionary:
	var location := WorldLocationData.find_current(EventState.get_tree())
	var events: Array[Dictionary] = []
	for event: CalendarEventData in EventState.get_active_events(location.id if location != null else &""):
		events.append({"id": String(event.id), "name": event.display_name, "location_id": String(event.location_id)})
	return {"active_events": events}

## The ways to get items the module gives (`ItemSources`): a crop's harvest,
## a fish, what is foraged and mined, an animal's products, a machine's
## output, and the rewards of a festival and of a collection's milestone. A
## harvest and a forage name their seasons, a fish its seasons, hours and
## weather ("Caught at River (Spring · 06:00–20:00 · Rain)",
## `FishData.describe_when()`), and a rock of the mine the floor it is first
## found on ("Mined from Gold Vein (from floor 20)"), so the player knows when
## and where to look.
static func find_item_sources(registry: ContentRegistry, sources: ItemSources) -> void:
	var seeds := {}
	for item: ItemData in registry.get_entries(ItemData.KIND):
		if item.crop_id != &"" and not seeds.has(item.crop_id):
			seeds[item.crop_id] = String(TranslationServer.translate(item.display_name))
	for crop: CropData in registry.get_entries(CropData.KIND):
		var planted: String = seeds.get(crop.id, String(TranslationServer.translate(crop.display_name)))
		var grown_in := describe_seasons(crop.allowed_seasons)
		if grown_in.is_empty():
			sources.add(crop.harvest_item_id, TranslationServer.translate("Grown from %s") % planted)
		else:
			sources.add(crop.harvest_item_id, TranslationServer.translate("Grown from %s (%s)") % [planted, grown_in])
	for fish: FishData in registry.get_entries(FishData.KIND):
		var bites := fish.describe_when(registry)
		if bites.is_empty():
			sources.add(fish.item_id, _found_at(registry, fish.locations, TranslationServer.translate("Caught at %s"), TranslationServer.translate("Caught while fishing")))
		else:
			sources.add(fish.item_id, _found_at(registry, fish.locations, TranslationServer.translate("Caught at %s (%s)"), TranslationServer.translate("Caught while fishing (%s)"), bites))
	for forage: ForageEntryData in registry.get_entries(ForageEntryData.KIND):
		var found_in := describe_seasons(forage.seasons)
		if found_in.is_empty():
			sources.add(forage.item_id, _found_at(registry, forage.locations, TranslationServer.translate("Foraged at %s"), TranslationServer.translate("Foraged")))
		else:
			sources.add(forage.item_id, _found_at(registry, forage.locations, TranslationServer.translate("Foraged at %s (%s)"), TranslationServer.translate("Foraged (%s)"), found_in))
	var mine_rocks := _mine_rock_ids()
	for node: MiningNodeData in registry.get_entries(MiningNodeData.KIND):
		var rock_name := String(TranslationServer.translate(node.display_name))
		if mine_rocks.has(node.id) and node.minimum_mine_floor > 1:
			sources.add(node.drop_item_id, TranslationServer.translate("Mined from %s (from floor %d)") % [rock_name, node.minimum_mine_floor])
		else:
			sources.add(node.drop_item_id, TranslationServer.translate("Mined from %s") % rock_name)
	for animal: FarmAnimalData in registry.get_entries(FarmAnimalData.KIND):
		var produced: String = TranslationServer.translate("Produced by %s") % TranslationServer.translate(animal.display_name)
		sources.add(animal.product_item_id, produced)
		sources.add(animal.premium_product_item_id, produced)
	for recipe: ProcessingRecipeData in registry.get_entries(ProcessingRecipeData.KIND):
		sources.add(recipe.output_item_id, TranslationServer.translate("Processed from %s") % ItemSources.describe_amounts(registry, recipe.inputs))
	for event: CalendarEventData in registry.get_entries(CalendarEventData.KIND):
		sources.add_each(event.reward_items, TranslationServer.translate("Reward for %s") % TranslationServer.translate(event.display_name))
	for milestone: CollectionMilestoneData in registry.get_entries(CollectionMilestoneData.KIND):
		sources.add_each(milestone.reward_items, TranslationServer.translate("Reward for %s") % TranslationServer.translate(milestone.display_name))
	if MineState.floor_table != null and MineState.floor_table.chests != null:
		MineState.floor_table.chests.add_ways(sources, TranslationServer.translate("Found in chests in the mine"))

# The rocks the game's mine lays out on its floors (`MineFloorTable`), each
# from its `minimum_mine_floor` down.
static func _mine_rock_ids() -> Dictionary[StringName, bool]:
	var ids: Dictionary[StringName, bool] = {}
	var table := MineState.floor_table
	if table == null:
		return ids
	if table.default_rock_id != &"":
		ids[table.default_rock_id] = true
	for tier: MineRockTier in table.rock_tiers:
		if tier != null and tier.rock_id != &"":
			ids[tier.rock_id] = true
	return ids

## The translated names of `seasons` as a list ("Spring, Autumn"); "" for none,
## which is every season.
static func describe_seasons(seasons: PackedStringArray) -> String:
	var names := PackedStringArray()
	for season: String in seasons:
		names.append(String(TranslationServer.translate(season)))
	return GameText.list(names)

# `at` (translated already) naming the locations of `location_ids`, or
# `anywhere` without any; `when`, unless empty, fills either's second place.
static func _found_at(registry: ContentRegistry, location_ids: Array[StringName], at: String, anywhere: String, when := "") -> String:
	var names := PackedStringArray()
	for location_id: StringName in location_ids:
		var location := registry.get_entry(WorldLocationData.KIND, location_id) as WorldLocationData
		names.append(String(TranslationServer.translate(location.display_name)) if location != null else String(location_id))
	if when.is_empty():
		return anywhere if names.is_empty() else at % GameText.list(names)
	return anywhere % when if names.is_empty() else at % [GameText.list(names), when]

## The content the game puts in the module's slots must exist.
func _find_slot_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if MineState.floor_table != null:
		problems.append_array(MineState.floor_table.find_problems(registry))
	var reel := FishingState.reel_minigame_id
	if reel != &"" and not registry.has_entry(MiniGameDefinition.KIND, reel):
		problems.append("fishing reel minigame '%s' is not a minigame" % reel)
	return problems

func _fishing_save_block_reason() -> String:
	return tr("Finish fishing before saving") if FishingState.is_active() else ""
