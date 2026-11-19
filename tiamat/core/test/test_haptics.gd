extends GutTest

## What shakes (`Haptics`): the gamepad in use, its heavy motor only for a
## hard pulse; the phone played by touch; nothing on a keyboard or with
## vibration off. A sound whose cue rumbles shakes as it plays, even before it
## has its audio, less from afar, and the content check names a cue that
## rumbles wrong.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const AudioFixture := preload("res://tiamat/core/test/audio_fixture.gd")

const PAD := 7

var _using_gamepad := false
var _using_touch := false
var _vibration := true

func before_each() -> void:
	_using_gamepad = InputPrompts.using_gamepad
	_using_touch = InputPrompts.using_touch
	_vibration = GameSettings.vibration
	GameSettings.vibration = true

func after_each() -> void:
	ContentRegistry.active = ContentDB
	Input.stop_joy_vibration(PAD)
	InputPrompts.using_gamepad = _using_gamepad
	InputPrompts.using_touch = _using_touch
	InputPrompts.set("_gamepad_device", -1)
	GameSettings.vibration = _vibration

func test_the_gamepad_in_use_buzzes_and_thumps_only_when_hit_hard() -> void:
	InputPrompts.call("_use_gamepad", PAD)
	assert_eq(InputPrompts.get_gamepad_in_use(), PAD)
	assert_true(Haptics.pulse(0.3, 0.1))
	assert_eq(Input.get_joy_vibration_strength(PAD), Vector2(0.3, 0.0), "a tap runs the light motor alone")
	assert_almost_eq(Input.get_joy_vibration_duration(PAD), 0.1, 0.0001)
	assert_true(Haptics.pulse(0.75, 0.2))
	assert_almost_eq(Input.get_joy_vibration_strength(PAD), Vector2(0.75, 0.5), Vector2(0.0001, 0.0001), "a blow runs the heavy one too")
	assert_true(Haptics.pulse(4.0, 0.2))
	assert_eq(Input.get_joy_vibration_strength(PAD), Vector2(1.0, 1.0), "never harder than full")

func test_a_finger_on_a_phone_shakes_the_phone() -> void:
	InputPrompts.call("_set_using_touch", true)
	assert_eq(InputPrompts.get_gamepad_in_use(), -1)
	assert_true(Haptics.pulse(0.5, 0.05))

func test_nothing_shakes_on_a_keyboard_with_vibration_off_or_for_nothing() -> void:
	InputPrompts.call("_set_using_touch", false)
	InputPrompts.call("_set_using_gamepad", false)
	assert_false(Haptics.pulse(1.0, 0.1), "a keyboard and mouse feel nothing")
	InputPrompts.call("_use_gamepad", PAD)
	assert_false(Haptics.pulse(0.0, 0.1))
	assert_false(Haptics.pulse(1.0, 0.0))
	GameSettings.vibration = false
	assert_false(Haptics.pulse(1.0, 0.1), "the player turned it off")
	assert_eq(Input.get_joy_vibration_strength(PAD), Vector2.ZERO)

func test_vibration_is_offered_with_a_gamepad_or_on_a_phone() -> void:
	assert_eq(Haptics.is_offered(), InputPromptService.starts_on_touch() or not Input.get_connected_joypads().is_empty())

func test_a_sound_that_rumbles_shakes_as_it_plays_and_less_from_afar() -> void:
	var thud := AudioFixture.cue(&"fixture_thud", AudioCueData.CueType.SFX)
	thud.rumble = 0.8
	thud.rumble_seconds = 0.15
	thud.hearing_distance = 300.0
	var song := AudioFixture.cue(&"fixture_song", AudioCueData.CueType.MUSIC)
	song.rumble = 1.0
	ContentFixture.use(self, [thud, song])
	InputPrompts.call("_use_gamepad", PAD)
	assert_false(GameAudio.play_cue(&"fixture_thud"), "nothing to hear yet")
	assert_almost_eq(Input.get_joy_vibration_strength(PAD), Vector2(0.8, 0.6), Vector2(0.0001, 0.0001), "but felt all the same")
	assert_almost_eq(Input.get_joy_vibration_duration(PAD), 0.15, 0.0001)
	var viewport := get_viewport()
	var centre := viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect().get_center()
	GameAudio.play_cue_at(&"fixture_thud", centre + Vector2(150.0, 0.0))
	assert_almost_eq(Input.get_joy_vibration_strength(PAD), Vector2(0.4, 0.0), Vector2(0.0001, 0.0001), "half as hard from half its hearing distance")
	Input.stop_joy_vibration(PAD)
	GameAudio.play_cue_at(&"fixture_thud", centre + Vector2(0.0, 400.0))
	assert_eq(Input.get_joy_vibration_strength(PAD), Vector2.ZERO, "out of hearing, out of feeling")
	GameAudio.play_cue(&"fixture_song")
	assert_eq(Input.get_joy_vibration_strength(PAD), Vector2.ZERO, "music never shakes")
	GameAudio.stop_music()

func test_the_content_check_names_a_cue_that_rumbles_wrong() -> void:
	var song := AudioFixture.cue(&"fixture_song", AudioCueData.CueType.MUSIC)
	song.rumble = 0.5
	var timeless := AudioFixture.cue(&"fixture_timeless", AudioCueData.CueType.SFX)
	timeless.rumble = 0.5
	timeless.rumble_seconds = 0.0
	var wild := AudioFixture.cue(&"fixture_wild", AudioCueData.CueType.SFX)
	wild.rumble = 1.5
	var registry := ContentFixture.use(self, [song, timeless, wild])
	assert_eq(song.find_problems(registry), PackedStringArray(["is music, which never rumbles"]))
	assert_eq(timeless.find_problems(registry), PackedStringArray(["rumbles for no time"]))
	assert_eq(wild.find_problems(registry), PackedStringArray(["rumbles at 1.5, outside 0 to 1"]))

func test_the_settings_turn_vibration_off() -> void:
	var menu := (load("res://tiamat/core/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	add_child_autofree(menu)
	menu.open()
	assert_eq(menu.vibration_check.visible, Haptics.is_offered(), "offered when the player holds something that shakes")
	assert_true(menu.vibration_check.button_pressed)
	InputPrompts.call("_use_gamepad", PAD)
	menu.vibration_check.button_pressed = false
	assert_false(GameSettings.vibration, "the toggle sets it")
	assert_eq(Input.get_joy_vibration_strength(PAD), Vector2.ZERO)
	menu.vibration_check.button_pressed = true
	assert_true(GameSettings.vibration)
	assert_eq(Input.get_joy_vibration_strength(PAD), Vector2(0.5, 0.0), "turned on, it shakes once to be felt")
