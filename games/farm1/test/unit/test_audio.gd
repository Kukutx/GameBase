extends GutTest

func after_each() -> void:
	GameAudio.stop_music()
	GameAudio.stop_all_sfx()

func test_audio_cues_and_location_music_are_registered() -> void:
	var errors := ContentDB.rebuild()
	assert_eq(errors.size(), 0)
	var cues := AudioCueData.find_all()
	assert_eq(cues.size(), 18)

	var expected_sfx: Array[StringName] = [
		&"sfx_pickup",
		&"sfx_harvest",
		&"sfx_gift",
		&"sfx_fish_caught",
		&"sfx_resource_mined",
		&"sfx_enemy_defeated",
		&"sfx_processing_complete",
		&"sfx_tool_upgraded",
		&"sfx_swing",
		&"sfx_hit",
		&"sfx_hurt",
		&"sfx_purchase",
		&"sfx_sale",
	]
	for cue_id: StringName in expected_sfx:
		var cue := AudioCueData.find(cue_id)
		assert_not_null(cue, "Missing SFX cue %s" % cue_id)
		if cue != null:
			assert_false(cue.is_music())
			assert_eq(cue.get_bus(), &"Sounds")

	var expected_music := {
		&"starter_town": &"music_starter_town",
		&"riverside_town": &"music_riverside_town",
		&"harbor_town": &"music_harbor_town",
		&"player_home": &"music_player_home",
		&"old_mine": &"music_old_mine",
	}
	for raw_location_id: Variant in expected_music.keys():
		var location_id := raw_location_id as StringName
		var cue_id := expected_music[raw_location_id] as StringName
		var location := WorldLocationData.find(location_id)
		var cue := AudioCueData.find(cue_id)
		assert_not_null(location)
		assert_not_null(cue)
		if location != null and cue != null:
			assert_eq(location.music_cue_id, cue_id)
			assert_true(cue.is_music())
			assert_eq(cue.get_bus(), &"Music")

func test_the_game_bus_layout_has_music_and_sounds_buses() -> void:
	assert_gte(AudioServer.get_bus_index(&"Master"), 0)
	assert_gte(AudioServer.get_bus_index(&"Music"), 0)
	assert_gte(AudioServer.get_bus_index(&"Sounds"), 0)

func test_gameplay_audio_mapping_requests_stable_cue_ids() -> void:
	var requested: Array[StringName] = []
	var on_requested := func(cue_id: StringName) -> void:
		requested.append(cue_id)
	GameAudio.cue_requested.connect(on_requested)
	# Call GameAudio's own handlers only; emitting the signals would also
	# advance quests, contracts and collections.
	_call_audio_handler(&"LifesimEvents.fish_caught", [&"river_trout", &"river_trout"])
	_call_audio_handler(&"LifesimEvents.resource_mined", [&"stone_rock", &"stone", 1])
	_call_audio_handler(&"ProgressionEvents.tool_upgraded", [&"copper_pickaxe", &"copper_pickaxe"])
	assert_eq(requested, [&"sfx_fish_caught", &"sfx_resource_mined", &"sfx_tool_upgraded"])
	GameAudio.cue_requested.disconnect(on_requested)

func _call_audio_handler(event: StringName, arguments: Array) -> void:
	var listener: GameEventListener = GameAudio._event_listeners.get(event)
	if listener == null or not listener.is_listening():
		fail_test("GameAudio does not listen to %s" % event)
		return
	listener._relay.callv(arguments)
