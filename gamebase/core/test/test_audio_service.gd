extends GutTest

## The GameAudio service on audio cues the test builds: its players, playback
## of SFX and music on their buses, a silent request for a cue without a
## stream, and the event cues a `GameDefinition` wires as `<Autoload>.<signal>`.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

## Stands in for an autoload that announces events: a direct child of the root.
class _FixtureEventSource extends Node:
	signal fixture_happened(subject: StringName, amount: int)

## Buses a test added because the game's bus layout lacks them.
var _added_buses: Array[StringName] = []

func after_each() -> void:
	# GUT frees the fixture after this; restore against the game's content.
	ContentRegistry.active = ContentDB
	GameAudio.stop_music()
	GameAudio.stop_all_sfx()
	for bus: StringName in _added_buses:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.remove_bus(index)
	_added_buses.clear()

func test_the_service_has_a_music_player_and_sfx_channels() -> void:
	assert_not_null(GameAudio.get_node_or_null("MusicPlayer"))
	for index in range(GameAudioService.SFX_CHANNEL_COUNT):
		assert_not_null(GameAudio.get_node_or_null("Sfx%d" % index), "SFX channel %d" % index)

func test_a_cue_without_a_stream_is_a_safe_silent_request() -> void:
	var cue := _cue(&"fixture_placeholder", AudioCueData.CueType.SFX, null)
	ContentFixture.use(self, [cue])
	var requested: Array[StringName] = []
	var on_requested := func(cue_id: StringName) -> void:
		requested.append(cue_id)
	GameAudio.cue_requested.connect(on_requested)
	assert_false(GameAudio.play_cue(&"fixture_placeholder"))
	assert_false(GameAudio.play_cue(&"fixture_missing"))
	GameAudio.cue_requested.disconnect(on_requested)
	assert_eq(requested, [&"fixture_placeholder", &"fixture_missing"])

func test_sfx_and_music_play_on_their_buses() -> void:
	var sfx := _cue(&"fixture_sfx", AudioCueData.CueType.SFX, _make_test_stream())
	var music := _cue(&"fixture_music", AudioCueData.CueType.MUSIC, _make_test_stream())
	ContentFixture.use(self, [sfx, music])
	assert_eq(sfx.get_bus(), &"Sounds")
	assert_eq(music.get_bus(), &"Music")
	_ensure_bus(&"Sounds")
	_ensure_bus(&"Music")
	var started: Array[StringName] = []
	var on_started := func(cue_id: StringName) -> void:
		started.append(cue_id)
	GameAudio.cue_started.connect(on_started)

	assert_true(GameAudio.play_cue(&"fixture_sfx"))
	var sfx_player := _player_with(sfx.stream)
	assert_not_null(sfx_player, "an SFX channel plays the cue's stream")
	if sfx_player != null:
		assert_eq(sfx_player.bus, &"Sounds")

	assert_true(GameAudio.play_cue(&"fixture_music"))
	var music_player := GameAudio.get_node("MusicPlayer") as AudioStreamPlayer
	assert_eq(music_player.stream, music.stream)
	assert_eq(music_player.bus, &"Music")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_music")
	GameAudio.cue_started.disconnect(on_started)
	assert_eq(started, [&"fixture_sfx", &"fixture_music"])

func test_an_event_cue_plays_whenever_its_signal_fires() -> void:
	var cue := _cue(&"fixture_chime", AudioCueData.CueType.SFX, _make_test_stream())
	ContentFixture.use(self, [cue])
	var source := _FixtureEventSource.new()
	source.name = "FixtureEventSource"
	get_tree().root.add_child(source)
	autofree(source)
	var definition := GameDefinition.new()
	definition.event_cues = {&"FixtureEventSource.fixture_happened": &"fixture_chime"}
	# A service wires the event cues of the running game's definition when it
	# starts; start one on the fixture definition.
	var service: GameAudioService = ContentFixture.with_definition(definition, func() -> GameAudioService:
		var started := GameAudioService.new()
		add_child_autofree(started)
		return started
	)
	var requested: Array[StringName] = []
	service.cue_requested.connect(func(cue_id: StringName) -> void:
		requested.append(cue_id)
	)
	watch_signals(service)

	source.fixture_happened.emit(&"fixture_subject", 3)
	source.fixture_happened.emit(&"fixture_subject", 4)
	assert_eq(requested, [&"fixture_chime", &"fixture_chime"], "the signal's own arguments are dropped")
	assert_signal_emit_count(service, "cue_started", 2)
	# The service syncs the location music a frame after it starts; let that
	# finish before GUT frees it.
	await wait_process_frames(3)

func _cue(id: StringName, cue_type: AudioCueData.CueType, stream: AudioStream) -> AudioCueData:
	var cue := AudioCueData.new()
	cue.id = id
	cue.cue_type = cue_type
	cue.stream = stream
	return cue

func _make_test_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	stream.stereo = false
	stream.data = PackedByteArray([128, 132, 128, 124, 128, 132, 128, 124])
	return stream

## The SFX channel of GameAudio that holds `stream`, or null.
func _player_with(stream: AudioStream) -> AudioStreamPlayer:
	for child: Node in GameAudio.get_children():
		if child is AudioStreamPlayer and child.name != &"MusicPlayer" and (child as AudioStreamPlayer).stream == stream:
			return child as AudioStreamPlayer
	return null

## Adds `bus` when the game's bus layout lacks it (a player on a missing bus
## reports Master); `after_each()` removes it again.
func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_added_buses.append(bus)
