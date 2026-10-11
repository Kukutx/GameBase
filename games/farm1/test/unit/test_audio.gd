extends GutTest

func _make_test_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	stream.stereo = false
	stream.data = PackedByteArray([128, 132, 128, 124, 128, 132, 128, 124])
	return stream

func after_each() -> void:
	GameAudio.stop_music()
	GameAudio.stop_all_sfx()

func test_audio_cues_and_location_music_are_registered() -> void:
	var errors := ContentDB.rebuild()
	assert_eq(errors.size(), 0)
	var cues := ContentDB.get_all_audio_cues()
	assert_eq(cues.size(), 13)

	var expected_sfx: Array[StringName] = [
		&"sfx_pickup",
		&"sfx_harvest",
		&"sfx_gift",
		&"sfx_fish_caught",
		&"sfx_resource_mined",
		&"sfx_enemy_defeated",
		&"sfx_processing_complete",
		&"sfx_tool_upgraded",
	]
	for cue_id: StringName in expected_sfx:
		var cue := ContentDB.get_audio_cue(cue_id)
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
		var location := ContentDB.get_location(location_id)
		var cue := ContentDB.get_audio_cue(cue_id)
		assert_not_null(location)
		assert_not_null(cue)
		if location != null and cue != null:
			assert_eq(location.music_cue_id, cue_id)
			assert_true(cue.is_music())
			assert_eq(cue.get_bus(), &"Music")

func test_audio_buses_and_autoload_are_available() -> void:
	assert_gte(AudioServer.get_bus_index(&"Master"), 0)
	assert_gte(AudioServer.get_bus_index(&"Music"), 0)
	assert_gte(AudioServer.get_bus_index(&"Sounds"), 0)
	assert_not_null(GameAudio.get_node_or_null("MusicPlayer"))
	assert_not_null(GameAudio.get_node_or_null("Sfx0"))

func test_placeholder_cue_is_safe_silent_request() -> void:
	var cue := ContentDB.get_audio_cue(&"sfx_pickup")
	assert_not_null(cue)
	if cue == null:
		return
	var original := cue.stream
	cue.stream = null
	var requested: Array[StringName] = []
	var on_requested := func(cue_id: StringName) -> void:
		requested.append(cue_id)
	GameAudio.cue_requested.connect(on_requested)
	assert_false(GameAudio.play_cue(&"sfx_pickup"))
	assert_eq(requested, [&"sfx_pickup"])
	GameAudio.cue_requested.disconnect(on_requested)
	cue.stream = original

func test_sfx_and_music_route_to_expected_buses() -> void:
	var sfx := ContentDB.get_audio_cue(&"sfx_fish_caught")
	var music := ContentDB.get_audio_cue(&"music_old_mine")
	assert_not_null(sfx)
	assert_not_null(music)
	if sfx == null or music == null:
		return

	var original_sfx := sfx.stream
	var original_music := music.stream
	sfx.stream = _make_test_stream()
	music.stream = _make_test_stream()

	var started: Array[StringName] = []
	var on_started := func(cue_id: StringName) -> void:
		started.append(cue_id)
	GameAudio.cue_started.connect(on_started)

	assert_true(GameAudio.play_cue(&"sfx_fish_caught"))
	var sfx_player := GameAudio.get_node("Sfx0") as AudioStreamPlayer
	assert_eq(sfx_player.bus, &"Sounds")
	assert_eq(sfx_player.stream, sfx.stream)

	assert_true(GameAudio.play_cue(&"music_old_mine"))
	var music_player := GameAudio.get_node("MusicPlayer") as AudioStreamPlayer
	assert_eq(music_player.bus, &"Music")
	assert_eq(music_player.stream, music.stream)
	assert_eq(GameAudio.get_current_music_cue_id(), &"music_old_mine")
	assert_true(started.has(&"sfx_fish_caught"))
	assert_true(started.has(&"music_old_mine"))

	GameAudio.cue_started.disconnect(on_started)
	sfx.stream = original_sfx
	music.stream = original_music

func test_gameplay_audio_mapping_requests_stable_cue_ids() -> void:
	var requested: Array[StringName] = []
	var on_requested := func(cue_id: StringName) -> void:
		requested.append(cue_id)
	GameAudio.cue_requested.connect(on_requested)
	# Call GameAudio's own handlers only; emitting the signals would also
	# advance quests, contracts and collections.
	_call_audio_handler(GameEvents.fish_caught, [&"river_trout", &"river_trout"])
	_call_audio_handler(GameEvents.resource_mined, [&"stone_rock", &"stone", 1])
	_call_audio_handler(GameEvents.tool_upgraded, [&"copper_pickaxe", &"copper_pickaxe"])
	assert_eq(requested, [&"sfx_fish_caught", &"sfx_resource_mined", &"sfx_tool_upgraded"])
	GameAudio.cue_requested.disconnect(on_requested)

func _call_audio_handler(event: Signal, arguments: Array) -> void:
	for connection: Dictionary in event.get_connections():
		var handler: Callable = connection["callable"]
		if handler.get_object() == GameAudio:
			handler.callv(arguments)
			return
	fail_test("GameAudio does not listen to %s" % event.get_name())
