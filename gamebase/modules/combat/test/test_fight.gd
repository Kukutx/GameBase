extends GutTest

## A fight (`FightState`): it starts with the first creature that hunts the
## player and ends once none has for the calm, at once when the player leaves
## the scene or is taken out of play; its music plays over the location's
## while it lasts.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const AudioFixture := preload("res://gamebase/core/test/audio_fixture.gd")

var _settings: CombatSettings

func before_each() -> void:
	_settings = CombatSettings.new()
	_settings.fight_music_cue_id = &"fixture_fight_music"
	_settings.fight_calm_seconds = 0.0
	ContentFixture.use(self, [AudioFixture.cue(&"fixture_fight_music", AudioCueData.CueType.MUSIC, AudioFixture.stream())])
	ContentFixture.use_settings(self, [_settings])
	FightState.end_fight()

func after_each() -> void:
	FightState.end_fight()
	ContentRegistry.active = ContentDB
	GameAudio.stop_music()

func test_the_first_hunter_starts_a_fight_with_its_music_and_the_last_to_stop_ends_it() -> void:
	watch_signals(CombatEvents)
	var first: Node = autofree(Node.new())
	var second: Node = autofree(Node.new())
	FightState.set_hunting(first, true)
	assert_true(FightState.is_fighting())
	assert_true(GameAudio.has_pushed_music(FightService.MUSIC_LAYER))
	assert_eq(GameAudio.get_current_music_cue_id(), &"fixture_fight_music")
	FightState.set_hunting(second, true)
	FightState.set_hunting(first, true)
	assert_eq(FightState.get_hunter_count(), 2)
	assert_signal_emit_count(CombatEvents, "fight_started", 1)
	FightState.set_hunting(first, false)
	assert_true(FightState.is_fighting(), "one still hunts")
	FightState.set_hunting(second, false)
	assert_false(FightState.is_fighting())
	assert_false(GameAudio.has_pushed_music(FightService.MUSIC_LAYER))
	assert_eq(GameAudio.get_current_music_cue_id(), &"")
	assert_signal_emit_count(CombatEvents, "fight_ended", 1)
	FightState.set_hunting(second, false)
	assert_signal_emit_count(CombatEvents, "fight_ended", 1, "a creature that hunts no more ends nothing")

func test_a_fight_calms_down_after_its_seconds_unless_a_hunter_comes_back() -> void:
	_settings.fight_calm_seconds = 0.1
	var hunter: Node = autofree(Node.new())
	FightState.set_hunting(hunter, true)
	FightState.set_hunting(hunter, false)
	assert_true(FightState.is_fighting(), "it calms down first")
	FightState.set_hunting(hunter, true)
	await wait_seconds(0.25)
	assert_true(FightState.is_fighting(), "a hunter back keeps it on")
	FightState.set_hunting(hunter, false)
	await wait_seconds(0.25)
	assert_false(FightState.is_fighting())

func test_leaving_the_scene_ends_the_fight_at_once() -> void:
	_settings.fight_calm_seconds = 10.0
	var hunter: Node = autofree(Node.new())
	FightState.set_hunting(hunter, true)
	# Its hunters left with the scene before.
	FightState.set_hunting(hunter, false)
	FightState._on_scene_changed()
	assert_false(FightState.is_fighting())

func test_taking_the_player_out_of_play_ends_the_fight_at_once() -> void:
	_settings.fight_calm_seconds = 10.0
	var hunter: Node = autofree(Node.new())
	FightState.set_hunting(hunter, true)
	# Passing out, a load, a new game or the title.
	GameSession.end_activities()
	assert_false(FightState.is_fighting(), "though a creature still hunted")
	assert_false(GameAudio.has_pushed_music(FightService.MUSIC_LAYER))
	assert_eq(FightState.get_hunter_count(), 0)
