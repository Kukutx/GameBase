extends "res://gamebase/core/test/runtime_smoke.gd"

const YEARS_TO_SOAK := 3
const MORNING_MINUTE := 6 * 60

func _init() -> void:
	smoke_name = "LONG_HORIZON_SOAK"
	save_directory = "user://long_horizon_soak"

func _run() -> void:
	var world_clock := root.get_node("WorldClock")
	var weather_state := root.get_node("WeatherState")
	var event_state := root.get_node("EventState")
	var contract_state := root.get_node("DailyContractState")
	var save_manager := root.get_node("SaveManager")
	var player_state := root.get_node("PlayerState")
	var world_state := root.get_node("WorldState")
	var npc_memory := root.get_node("NpcMemory")
	# The game's calendar, loaded rather than named: this script compiles before
	# the autoloads exist. The checks below count its days independently.
	var calendar: Resource = load("res://gamebase/core/time/game_calendar.gd").call("current")
	var days_per_season := int(calendar.get("days_per_season"))
	var seasons_per_year := (calendar.get("season_names") as PackedStringArray).size()
	var total_days := YEARS_TO_SOAK * days_per_season * seasons_per_year
	var save_constants: Dictionary = (save_manager.get_script() as Script).get_script_constant_map()
	var current_save_version := int(save_constants.get("SAVE_VERSION", 0))

	var change_error := change_scene_to_file("res://game/world/dev_world.tscn")
	if change_error != OK:
		_fail("Could not open Starter Town for soak")
		return
	await scene_changed
	await process_frame
	world_clock.paused = true

	_check(current_scene != null and current_scene.scene_file_path == "res://game/world/dev_world.tscn", "Soak did not enter Starter Town")
	_check(get_first_node_in_group("player") != null, "Soak player missing")

	for day in range(1, total_days + 1):
		world_clock.set_time(day, MORNING_MINUTE)
		await process_frame

		var expected_season := posmod((day - 1) / days_per_season, seasons_per_year)
		var expected_season_day := posmod(day - 1, days_per_season) + 1
		var expected_year := int((day - 1) / (days_per_season * seasons_per_year)) + 1
		_check(world_clock.get_season_index() == expected_season, "Season index drifted on Day %d" % day)
		_check(world_clock.get_day_of_season() == expected_season_day, "Season day drifted on Day %d" % day)
		_check(event_state.get_year(day) == expected_year, "Calendar year drifted on Day %d" % day)
		_check(StringName(weather_state.get_weather_id()) == StringName(weather_state.get_weather_id(day)), "Weather cache drifted on Day %d" % day)

		var contract: Dictionary = contract_state.get_contract()
		_check(not contract.is_empty(), "Daily contract missing on Day %d" % day)
		if not contract.is_empty():
			_check(int(contract.get("generated_day", 0)) == day, "Daily contract did not rotate on Day %d" % day)
			_check(int(contract.get("expires_day", 0)) >= day, "Daily contract expired before generation on Day %d" % day)

		npc_memory.append_message(&"mira", &"system", "Soak day %d" % day)
		var memory: Array = npc_memory.get_recent_messages(&"mira")
		_check(memory.size() <= npc_memory.max_recent_messages, "NPC memory exceeded configured bound on Day %d" % day)
		if not memory.is_empty():
			_check(int(memory.back().get("day", 0)) == day, "NPC memory day marker drifted on Day %d" % day)

		world_state.set_value(&"soak:last_day", day)

		if day % days_per_season == 0:
			var checkpoint_index := day / days_per_season
			var marker_money := 20000 + day
			player_state.money = marker_money
			world_state.set_value(&"soak:checkpoint", checkpoint_index)

			_check(save_manager.get_save_block_reason().is_empty(), "Save guard blocked soak checkpoint Day %d: %s" % [day, save_manager.get_save_block_reason()])
			if not save_manager.save_game():
				_fail("Checkpoint save failed on Day %d" % day)
				break

			var raw: Dictionary = save_manager.call("_read_dictionary", save_manager.save_path)
			_check(int(raw.get("version", 0)) == current_save_version, "Checkpoint schema mismatch on Day %d" % day)
			_check(String(raw.get("game_version", "")) == String(ProjectSettings.get_setting("application/config/version", "unknown")), "Checkpoint game provenance mismatch on Day %d" % day)
			_check(not String(raw.get("engine_version", "")).is_empty(), "Checkpoint engine provenance missing on Day %d" % day)
			var raw_clock: Variant = raw.get("clock", {})
			if raw_clock is Dictionary:
				_check(int((raw_clock as Dictionary).get("day", 0)) == day, "Checkpoint wrote wrong day on Day %d" % day)
			else:
				_fail("Checkpoint clock payload missing on Day %d" % day)

			# Deliberately corrupt in-memory state, then exercise the real disk
			# load + scene reconstruction path.
			world_clock.set_time(1, 0)
			player_state.money = 0
			world_state.set_value(&"soak:last_day", -1)
			world_state.set_value(&"soak:checkpoint", -1)
			npc_memory.clear()

			var loaded: bool = await save_manager.load_game()
			_check(loaded, "Checkpoint load failed on Day %d" % day)
			if not loaded:
				break
			await process_frame

			_check(current_scene != null and current_scene.scene_file_path == "res://game/world/dev_world.tscn", "Checkpoint load restored wrong scene on Day %d" % day)
			_check(get_first_node_in_group("player") != null, "Checkpoint load lost player on Day %d" % day)
			_check(world_clock.day == day and world_clock.minute_of_day == MORNING_MINUTE, "Clock did not restore on Day %d" % day)
			_check(player_state.money == marker_money, "Money did not restore on Day %d" % day)
			_check(int(world_state.get_value(&"soak:last_day", -1)) == day, "World state did not restore last day %d" % day)
			_check(int(world_state.get_value(&"soak:checkpoint", -1)) == checkpoint_index, "World checkpoint did not restore on Day %d" % day)
			var restored_memory: Array = npc_memory.get_recent_messages(&"mira")
			_check(restored_memory.size() == mini(day, npc_memory.max_recent_messages), "Bounded NPC memory size did not restore on Day %d" % day)
			if not restored_memory.is_empty():
				_check(int(restored_memory.back().get("day", 0)) == day, "Newest NPC memory did not restore on Day %d" % day)
			_check(StringName(weather_state.get_weather_id()) == StringName(weather_state.get_weather_id(day)), "Weather did not reconcile after load on Day %d" % day)
			_check(event_state.get_year() == expected_year, "Event year did not reconcile after load on Day %d" % day)

	# Cross the three-year boundary after the final round trip.
	world_clock.set_time(total_days + 1, MORNING_MINUTE)
	await process_frame
	_check(world_clock.get_season_index() == 0, "Day %d did not roll back to Spring" % (total_days + 1))
	_check(world_clock.get_day_of_season() == 1, "Day %d was not Spring 1" % (total_days + 1))
	_check(event_state.get_year() == YEARS_TO_SOAK + 1, "Day %d did not enter Year %d" % [total_days + 1, YEARS_TO_SOAK + 1])
	var year_four_contract: Dictionary = contract_state.get_contract()
	_check(int(year_four_contract.get("generated_day", 0)) == total_days + 1, "Year %d daily contract did not rotate" % (YEARS_TO_SOAK + 1))
