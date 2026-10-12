extends GutTest

## The sounds of `GameAudio` on cues the test builds: its channels, a silent
## request for a cue without a stream, sounds and music on their buses, how
## many of a cue and of all play at once, a sound heard from a place, the event
## cues a `GameDefinition` wires as `<Autoload>.<signal>` (from where the event
## happened when it says), the menus' sounds and what the content check says
## of the cues the definition names.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const AudioFixture := preload("res://gamebase/core/test/audio_fixture.gd")

const SFX := AudioCueData.CueType.SFX
const MUSIC := AudioCueData.CueType.MUSIC

## Stands in for an autoload that announces events: a direct child of the root.
class _FixtureEventSource extends Node:
	signal fixture_happened(subject: StringName, amount: int)
	signal fixture_landed(subject: StringName, position: Vector2)

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

func test_the_service_has_two_music_players_and_its_sound_channels() -> void:
	for index in range(2):
		assert_not_null(GameAudio.get_node_or_null("Music%d" % index), "music player %d" % index)
	for index in range(GameAudioService.SFX_CHANNEL_COUNT):
		assert_true(GameAudio.get_node_or_null("Sfx%d" % index) is AudioStreamPlayer, "SFX channel %d" % index)
	for index in range(GameAudioService.POSITIONAL_CHANNEL_COUNT):
		assert_true(GameAudio.get_node_or_null("Positional%d" % index) is AudioStreamPlayer2D, "positional channel %d" % index)

func test_a_cue_without_a_stream_is_a_safe_silent_request() -> void:
	ContentFixture.use(self, [AudioFixture.cue(&"fixture_placeholder", SFX)])
	var requested: Array[StringName] = []
	var on_requested := func(cue_id: StringName) -> void:
		requested.append(cue_id)
	GameAudio.cue_requested.connect(on_requested)
	assert_false(GameAudio.play_cue(&"fixture_placeholder"))
	assert_false(GameAudio.play_cue(&"fixture_missing"))
	assert_false(GameAudio.play_cue_at(&"fixture_placeholder", Vector2.ONE))
	GameAudio.cue_requested.disconnect(on_requested)
	assert_eq(requested, [&"fixture_placeholder", &"fixture_missing", &"fixture_placeholder"])

func test_sfx_and_music_play_on_their_buses() -> void:
	var sfx := AudioFixture.cue(&"fixture_sfx", SFX, AudioFixture.stream())
	var music := AudioFixture.cue(&"fixture_music", MUSIC, AudioFixture.stream())
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
	var sfx_players := AudioFixture.players_of(GameAudio, sfx.stream)
	assert_eq(sfx_players.size(), 1, "an SFX channel plays the cue's stream")
	if not sfx_players.is_empty():
		assert_eq(sfx_players[0].get(&"bus"), &"Sounds")

	assert_true(GameAudio.play_cue(&"fixture_music"))
	var music_players := AudioFixture.players_of(GameAudio, music.stream)
	assert_eq(music_players.size(), 1)
	if not music_players.is_empty():
		assert_eq(music_players[0].get(&"bus"), &"Music")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_music")
	GameAudio.cue_started.disconnect(on_started)
	assert_eq(started, [&"fixture_sfx", &"fixture_music"])

func test_a_cue_plays_its_most_voices_at_once_and_one_more_stops_its_oldest() -> void:
	var step := AudioFixture.cue(&"fixture_step", SFX, AudioFixture.stream())
	step.max_voices = 2
	var bell := AudioFixture.cue(&"fixture_bell", SFX, AudioFixture.stream())
	ContentFixture.use(self, [step, bell])
	GameAudio.play_cue(&"fixture_step")
	var oldest := AudioFixture.players_of(GameAudio, step.stream)[0]
	GameAudio.play_cue(&"fixture_bell")
	GameAudio.play_cue(&"fixture_step")
	GameAudio.play_cue(&"fixture_step")
	var steps := AudioFixture.players_of(GameAudio, step.stream)
	assert_eq(steps.size(), 2, "never more than its voices")
	assert_true(steps.has(oldest), "the oldest voice's channel plays the newest")
	assert_eq(AudioFixture.players_of(GameAudio, bell.stream).size(), 1, "another cue keeps its own")

func test_past_the_channels_the_sound_that_played_longest_stops() -> void:
	var cues: Array = []
	for index in range(GameAudioService.SFX_CHANNEL_COUNT + 1):
		cues.append(AudioFixture.cue(StringName("fixture_sound_%d" % index), SFX, AudioFixture.stream()))
	ContentFixture.use(self, cues)
	for cue: AudioCueData in cues:
		assert_true(GameAudio.play_cue(cue.id))
	assert_eq(AudioFixture.players_of(GameAudio, (cues[0] as AudioCueData).stream).size(), 0, "the first stopped")
	for index in range(1, cues.size()):
		assert_eq(AudioFixture.players_of(GameAudio, (cues[index] as AudioCueData).stream).size(), 1)

func test_a_sound_played_at_a_place_is_heard_from_there() -> void:
	var splash := AudioFixture.cue(&"fixture_splash", SFX, AudioFixture.stream())
	splash.hearing_distance = 300.0
	ContentFixture.use(self, [splash])
	assert_true(GameAudio.play_cue_at(&"fixture_splash", Vector2(120, -40)))
	var players := AudioFixture.players_of(GameAudio, splash.stream)
	assert_eq(players.size(), 1)
	var player := players[0] as AudioStreamPlayer2D
	assert_not_null(player, "a positional channel plays it")
	if player != null:
		assert_eq(player.global_position, Vector2(120, -40))
		assert_eq(player.max_distance, 300.0)

func test_an_event_cue_plays_whenever_its_signal_fires_and_from_where_it_happened() -> void:
	var chime := AudioFixture.cue(&"fixture_chime", SFX, AudioFixture.stream())
	var thud := AudioFixture.cue(&"fixture_thud", SFX, AudioFixture.stream())
	ContentFixture.use(self, [chime, thud])
	var source := _FixtureEventSource.new()
	source.name = "FixtureEventSource"
	get_tree().root.add_child(source)
	autofree(source)
	var definition := GameDefinition.new()
	definition.event_cues = {&"FixtureEventSource.fixture_happened": &"fixture_chime", &"FixtureEventSource.fixture_landed": &"fixture_thud"}
	var service := _start_service(definition)
	var requested: Array[StringName] = []
	service.cue_requested.connect(func(cue_id: StringName) -> void:
		requested.append(cue_id)
	)
	watch_signals(service)

	source.fixture_happened.emit(&"fixture_subject", 3)
	source.fixture_happened.emit(&"fixture_subject", 4)
	assert_eq(requested, [&"fixture_chime", &"fixture_chime"], "the signal's own arguments are dropped")
	assert_signal_emit_count(service, "cue_started", 2)
	source.fixture_landed.emit(&"fixture_subject", Vector2(64, 32))
	var landed := AudioFixture.players_of(service, thud.stream)
	assert_eq(landed.size(), 1)
	if not landed.is_empty():
		assert_true(landed[0] is AudioStreamPlayer2D, "an event that says where it happened sounds from there")
		assert_eq((landed[0] as Node2D).global_position, Vector2(64, 32))
	# The service syncs the location music a frame after it starts; let that
	# finish before GUT frees it.
	await wait_process_frames(3)

func test_the_menus_sound_once_a_frame_the_most_telling_first() -> void:
	var cues: Array = []
	for id: StringName in [&"fixture_focus", &"fixture_press", &"fixture_open", &"fixture_close"]:
		cues.append(AudioFixture.cue(id, SFX, AudioFixture.stream()))
	ContentFixture.use(self, cues)
	var definition := GameDefinition.new()
	definition.menu_focus_cue_id = &"fixture_focus"
	definition.menu_press_cue_id = &"fixture_press"
	definition.menu_open_cue_id = &"fixture_open"
	definition.menu_close_cue_id = &"fixture_close"
	var service := _start_service(definition)
	var requested: Array[StringName] = []
	service.cue_requested.connect(func(cue_id: StringName) -> void:
		requested.append(cue_id)
	)
	var menu := VBoxContainer.new()
	var button := Button.new()
	var next := Button.new()
	menu.add_child(button)
	menu.add_child(next)
	add_child_autofree(menu)

	# A button that opens a menu, which takes the focus: the menu opening sounds.
	button.pressed.emit()
	GameEvents.menu_opened.emit(&"fixture_menu")
	service.play_menu_sound(GameAudioService.MenuSound.FOCUS)
	await get_tree().process_frame
	assert_eq(requested, [&"fixture_open"])
	button.pressed.emit()
	await get_tree().process_frame
	assert_eq(requested, [&"fixture_open", &"fixture_press"], "any button in the tree sounds when pressed")
	button.grab_focus()
	await get_tree().process_frame
	assert_eq(requested, [&"fixture_open", &"fixture_press"], "a menu focusing its control is silent")
	var tab := InputEventAction.new()
	tab.action = &"ui_focus_next"
	tab.pressed = true
	get_viewport().push_input(tab)
	await get_tree().process_frame
	assert_true(next.has_focus())
	assert_eq(requested, [&"fixture_open", &"fixture_press", &"fixture_focus"], "the focus the player moves sounds")
	GameEvents.menu_closed.emit(&"fixture_menu")
	await get_tree().process_frame
	assert_eq(requested.back(), &"fixture_close")
	await wait_process_frames(2)

func test_the_content_check_names_cues_the_definition_or_a_cue_gets_wrong() -> void:
	var music := AudioFixture.cue(&"fixture_music", MUSIC)
	var odd := AudioFixture.cue(&"fixture_odd", SFX)
	odd.fade_seconds = -1.0
	odd.max_voices = 0
	odd.hearing_distance = 0.0
	var registry := ContentFixture.use(self, [music, odd])
	var definition := GameDefinition.new()
	definition.event_cues = {&"FixtureEvents.fixture_happened": &"fixture_missing"}
	definition.menu_open_cue_id = &"fixture_music"
	assert_eq(AudioCueData.find_definition_problems(definition, registry), PackedStringArray([
		"the event cues name 'FixtureEvents.fixture_happened', which is no signal of an autoload (<Autoload>.<signal>)",
		"the cue of event FixtureEvents.fixture_happened names unknown audio cue 'fixture_missing'",
		"the menu open sound names audio cue 'fixture_music', which is no sound",
	]))
	assert_eq(odd.find_problems(registry), PackedStringArray(["has a negative fade", "plays at most 0 at once", "is heard from no distance"]))
	assert_eq(AudioCueData.find_reference_problems(registry, "the fight music", &"fixture_odd", MUSIC), PackedStringArray(["the fight music names audio cue 'fixture_odd', which is no music"]))

# A service of its own on `definition`, which wires its event cues and menu
# sounds when it starts.
func _start_service(definition: GameDefinition) -> GameAudioService:
	return ContentFixture.with_definition(definition, func() -> GameAudioService:
		var started := GameAudioService.new()
		add_child_autofree(started)
		return started
	)

## Adds `bus` when the game's bus layout lacks it (a player on a missing bus
## reports Master); `after_each()` removes it again.
func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_added_buses.append(bus)
