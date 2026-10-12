class_name LifesimModule
extends GameModule

## Wires the life-sim module into the core (see `GameModule`).

func install() -> void:
	for kind_script: Script in [CalendarEventData, CropData, FarmAnimalData, FarmExpansionData, FishData,
			ForageEntryData, MiningNodeData, ProcessingRecipeData]:
		ContentDB.register_kind(kind_script.KIND, kind_script)
	ContentDB.register_check(CropData.find_seed_problems)
	ContentDB.register_check(FarmExpansionData.find_cycle_problems)
	ContentDB.register_check(_find_slot_problems)
	LifesimRules.register(GameRules)
	for action: StringName in [FarmPlot.TILL_ACTION, FarmPlot.WATER_ACTION, MiningNode.TOOL_ACTION, FishingSpot.TOOL_ACTION]:
		ItemData.register_tool_action(action)
	for stat: StringName in [&"tool_energy", &"farming_energy", &"mining_energy", &"fishing_wait", &"fishing_window",
			&"forage_quantity"]:
		GameStats.register_stat(stat)
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
