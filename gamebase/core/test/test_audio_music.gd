extends GutTest

## The music of `GameAudio` on cues the test builds: a track fades in while
## the one before fades out, music pushed over another plays until it is
## popped and the music beneath then comes back where it stopped, and music
## that plays already plays on.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const AudioFixture := preload("res://gamebase/core/test/audio_fixture.gd")

const MUSIC := AudioCueData.CueType.MUSIC

func after_each() -> void:
	ContentRegistry.active = ContentDB
	GameAudio.stop_music()

func test_a_track_fades_in_while_the_one_before_fades_out() -> void:
	var first := AudioFixture.cue(&"fixture_first", MUSIC, AudioFixture.stream(4.0))
	var second := AudioFixture.cue(&"fixture_second", MUSIC, AudioFixture.stream(4.0))
	second.fade_seconds = 0.2
	ContentFixture.use(self, [first, second])
	var changes: Array[StringName] = []
	var on_changed := func(cue_id: StringName) -> void:
		changes.append(cue_id)
	GameAudio.music_changed.connect(on_changed)

	assert_true(GameAudio.play_cue(&"fixture_first"))
	var first_player := _music_player(first.stream)
	assert_not_null(first_player)
	assert_almost_eq(first_player.volume_linear, 1.0, 0.001, "a cue that does not fade plays at its volume at once")
	assert_true(GameAudio.play_cue(&"fixture_second"))
	var second_player := _music_player(second.stream)
	assert_ne(second_player, first_player, "the next track plays on the other player")
	assert_almost_eq(second_player.volume_linear, 0.0, 0.001, "it starts silent")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_second")
	assert_true(await _until(func() -> bool: return first_player.stream == null), "the track before stops once it faded out")
	assert_almost_eq(second_player.volume_linear, 1.0, 0.01, "the new track is at its volume")
	assert_true(second_player.playing)

	assert_true(GameAudio.play_cue(&"fixture_second"))
	assert_eq(_music_player(second.stream), second_player, "the music that plays plays on")
	GameAudio.music_changed.disconnect(on_changed)
	assert_eq(changes, [&"fixture_first", &"fixture_second"])

func test_pushed_music_plays_until_popped_and_the_music_beneath_comes_back_where_it_stopped() -> void:
	var calm := AudioFixture.cue(&"fixture_calm", MUSIC, AudioFixture.stream(4.0))
	var fight := AudioFixture.cue(&"fixture_fight", MUSIC, AudioFixture.stream(4.0))
	ContentFixture.use(self, [calm, fight])
	GameAudio.play_cue(&"fixture_calm")
	_music_player(calm.stream).seek(1.5)

	GameAudio.push_music(&"fixture_layer", &"fixture_fight")
	assert_true(GameAudio.has_pushed_music(&"fixture_layer"))
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_fight")
	assert_null(_music_player(calm.stream), "the music beneath stops")
	GameAudio.play_cue(&"fixture_calm")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_fight", "music played meanwhile waits beneath")

	GameAudio.pop_music(&"fixture_layer")
	assert_false(GameAudio.has_pushed_music(&"fixture_layer"))
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_calm")
	var back := _music_player(calm.stream)
	assert_not_null(back)
	assert_almost_eq(back.get_playback_position(), 1.5, 0.05, "it comes back where it stopped")
	assert_null(_music_player(fight.stream))

func test_the_newest_pushed_music_plays_and_a_layer_below_it_goes_unheard() -> void:
	var calm := AudioFixture.cue(&"fixture_calm", MUSIC, AudioFixture.stream())
	var fight := AudioFixture.cue(&"fixture_fight", MUSIC, AudioFixture.stream())
	var game := AudioFixture.cue(&"fixture_game", MUSIC, AudioFixture.stream())
	ContentFixture.use(self, [calm, fight, game])
	GameAudio.play_cue(&"fixture_calm")
	GameAudio.push_music(&"fixture_fight_layer", &"fixture_fight")
	GameAudio.push_music(&"fixture_game_layer", &"fixture_game")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_game")
	GameAudio.pop_music(&"fixture_fight_layer")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_game", "a layer taken from beneath changes nothing heard")
	GameAudio.pop_music(&"fixture_game_layer")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_calm")
	GameAudio.pop_music(&"fixture_game_layer")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_calm", "popping again does nothing")

func test_a_place_without_music_fades_it_out_and_pushed_music_without_a_stream_is_silence() -> void:
	var calm := AudioFixture.cue(&"fixture_calm", MUSIC, AudioFixture.stream())
	var slot := AudioFixture.cue(&"fixture_slot", MUSIC)
	ContentFixture.use(self, [calm, slot])
	GameAudio.play_cue(&"fixture_calm")
	GameAudio.push_music(&"fixture_layer", &"fixture_slot")
	assert_eq(GameAudio.get_current_music_cue_id(), &"", "a slot waiting for its audio plays nothing")
	GameAudio.pop_music(&"fixture_layer")
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_calm")
	# The test's scene is no location of the game's.
	await GameAudio._sync_location_music()
	assert_eq(GameAudio.get_current_music_cue_id(), &"")
	assert_null(_music_player(calm.stream))

## The music player of GameAudio that holds `stream`, or null.
func _music_player(stream: AudioStream) -> AudioStreamPlayer:
	for player: Node in AudioFixture.players_of(GameAudio, stream):
		if String(player.name).begins_with("Music"):
			return player as AudioStreamPlayer
	return null

# Whether `condition` holds within `seconds`, on the tree's frames.
func _until(condition: Callable, seconds := 2.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true
