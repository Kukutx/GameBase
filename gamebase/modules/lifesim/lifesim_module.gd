class_name LifesimModule
extends GameModule

## Wires the life-sim module into the core (see `GameModule`).

func install() -> void:
	# Shipping restores its saved day marker before the clock (order 300) emits
	# day_changed, so loading never pays a day twice.
	SaveManager.register_section(SaveSection.new(&"shipping", 200,
		ShippingState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: ShippingState.load_save_data(section)))
	SaveManager.register_section(SaveSection.new(&"fishing", 1200,
		FishingState.to_save_data, func(section: Dictionary, _snapshot: Dictionary) -> void: FishingState.load_save_data(section)))
	# EventState keeps which festival is running only at runtime; rebuild it
	# from the restored clock and world flags.
	SaveManager.register_load_step(&"calendar_events", 200,
		func() -> void: EventState.refresh(WorldClock.day, WorldClock.minute_of_day))
	SaveManager.register_save_blocker(_fishing_save_block_reason)
	GameSession.register_new_game_step(&"animals", 300, AnimalState.reset_new_game)
	GameSession.register_new_game_step(&"shipping", 1000, ShippingState.reset_new_game)
	GameSession.register_new_game_step(&"fishing", 1100, FishingState.reset_new_game)

func _fishing_save_block_reason() -> String:
	return tr("Finish fishing before saving") if FishingState.is_active() else ""
