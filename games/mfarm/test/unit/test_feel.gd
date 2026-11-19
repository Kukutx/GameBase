extends GutTest

## What the old game showed and played around the rules: the opening comic
## and talk of a new game, weeds that sway, a harvest held up, boxes opened
## with the right mouse button and the time keys.

const IntroScene := preload("res://game/ui/intro.tscn")
const PlayerScene := preload("res://game/player/player.tscn")
const TimeKeys := preload("res://game/ui/time_keys.gd")
const MINUTES_PER_DAY := 24 * 60

var _state: Dictionary
var _day := 0
var _minute := 0

func before_each() -> void:
	_state = WorldState.to_save_data()
	WorldState.clear()
	_day = WorldClock.day
	_minute = WorldClock.minute_of_day

func after_each() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	InputLock.clear()
	WorldClock.paused = false
	WorldClock.set_time(_day, _minute)
	GameAudio.stop_music()
	WorldState.load_save_data(_state)

func test_the_intro_holds_the_player_and_the_clock_until_it_is_skipped() -> void:
	var intro := IntroScene.instantiate() as MFarmIntro
	add_child_autofree(intro)
	assert_false(intro.is_playing(), "it waits for a new game")
	watch_signals(intro)
	intro.play()
	assert_true(intro.is_playing())
	assert_true(InputLock.is_held(MFarmIntro.LOCK), "the player cannot act")
	assert_true(WorldClock.paused, "the clock stands still")
	assert_eq(GameAudio.get_current_music_cue_id(), MFarmIntro.MUSIC, "Calm 4 plays over the comic")
	var comic := intro.get_node("Comic") as Control
	assert_eq(comic.get_child_count(), MFarmIntro.COMIC.size() + 1, "every picture and the hint to skip")
	await wait_seconds(0.5)
	assert_gt((comic.get_child(0) as CanvasItem).modulate.a, 0.0, "the first picture fades in")
	assert_eq((comic.get_child(2) as CanvasItem).modulate.a, 0.0, "a later one waits for its time")
	intro.skip()
	assert_false(intro.is_playing())
	assert_signal_emitted(intro, "finished")
	assert_false(InputLock.is_held(MFarmIntro.LOCK))
	assert_false(WorldClock.paused)
	assert_false(GameAudio.has_pushed_music(MFarmIntro.MUSIC_LAYER))

func test_each_picture_of_the_comic_rests_in_view() -> void:
	var view := Rect2(Vector2.ZERO, Vector2(640, 360))
	for picture: Dictionary in MFarmIntro.COMIC:
		assert_not_null(load(MFarmIntro.ART % picture["art"]), picture["art"])
		var size: Vector2 = picture["size"] * MFarmIntro.CANVAS_SCALE
		var rect := Rect2(MFarmIntro._view_corner(picture["at"], size), size)
		assert_true(view.encloses(rect), "%s rests at %s" % [picture["art"], rect])
		var slide: Array = picture.get("slide", [])
		if not slide.is_empty():
			assert_eq(slide[-1][1], picture["at"], "%s slides to where it rests" % picture["art"])

func test_after_the_comic_the_farmer_looks_about_talks_and_looks_up() -> void:
	# The talk pauses the world; the test waits through it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := MFarmDialogueBox.new()
	add_child_autofree(box)
	var player := PlayerScene.instantiate() as MFarmPlayer
	add_child_autofree(player)
	var intro := IntroScene.instantiate() as MFarmIntro
	add_child_autofree(intro)
	assert_eq(intro.lines.size(), 4, "the old game's four lines")
	watch_signals(intro)
	intro.play()
	intro._end_comic()
	assert_eq(GameAudio.get_current_music_cue_id(), &"", "the comic's music ends with it")
	await wait_until(box.is_talking, MFarmIntro.TALK_AT + 1.0)
	assert_true(box.is_talking(), "the farmer meets Mike")
	assert_eq(player.facing, Vector2.DOWN, "after looking left and right")
	assert_true(intro.is_playing())
	box.stop()
	await wait_for_signal(intro.finished, MFarmIntro.LOOK_UP_SECONDS + 1.0)
	assert_eq(player.facing, Vector2.UP)
	assert_false(intro.is_playing())
	assert_false(InputLock.is_locked(), "the player has the controls back")

func test_a_weed_sways_away_and_stands_up_again() -> void:
	var weed := MFarmWorldItem.new()
	weed.item_id = &"grass_1"
	add_child_autofree(weed)
	weed.global_position = Vector2(100, 100)
	assert_true(weed.is_reapable())
	assert_true(weed.sway(50.0), "walked into from the left")
	await wait_seconds(MFarmWorldItem.SWAY_STEP_SECONDS * 2.5)
	var sprite := weed.get_node("Sprite") as Sprite2D
	assert_gt(sprite.rotation_degrees, 0.0, "it leans away, clockwise")
	assert_false(weed.sway(150.0), "a sway under way goes on")
	await wait_seconds(MFarmWorldItem.SWAY_STEP_SECONDS * (MFarmWorldItem.SWAY_STEPS.size() + 2))
	assert_eq(sprite.rotation_degrees, 0.0, "it stands up again")
	assert_true(weed.sway(150.0))

func test_a_harvest_is_held_up_for_a_moment() -> void:
	var player := PlayerScene.instantiate() as MFarmPlayer
	add_child_autofree(player)
	var held := player.get_node("Visual/HoldItem") as Sprite2D
	assert_false(held.visible)
	player.show_harvest(MFarmItemData.find(&"potato"))
	assert_true(held.visible, "the potato shows over the farmer's head")
	await wait_seconds(MFarmPlayer.HARVEST_SHOW_SECONDS + 0.2)
	assert_false(held.visible, "and goes into the bag")

func test_a_box_opens_with_the_right_mouse_button_only_from_next_to_it() -> void:
	var box := MFarmStorageBox.new()
	box.bag_id = &"empty_box"
	box.box_key = &"box:test"
	add_child_autofree(box)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	box._unhandled_input(click)
	assert_false(Bags.has_bag(&"box:test"), "too far away")
	var player := PlayerScene.instantiate() as MFarmPlayer
	add_child_autofree(player)
	box._on_trigger(player, true)
	assert_true(box.is_player_near())
	box._unhandled_input(click)
	assert_true(Bags.has_bag(&"box:test"), "opened from next to it")
	box._on_trigger(player, false)
	assert_false(box.is_player_near())

func test_g_moves_on_a_day_and_t_runs_the_clock_unless_the_controls_are_held() -> void:
	var keys := TimeKeys.new()
	add_child_autofree(keys)
	var day := WorldClock.day
	keys._unhandled_key_input(_key(KEY_G))
	assert_eq(WorldClock.day, day + 1)
	InputLock.lock(&"test", false)
	keys._unhandled_key_input(_key(KEY_G))
	assert_eq(WorldClock.day, day + 1, "not while a menu or a talk holds the controls")
	InputLock.unlock(&"test")
	keys._unhandled_key_input(_key(KEY_T))
	assert_true(keys.is_processing(), "holding T runs the clock")

func test_night_falls_slowly_but_a_skipped_day_shows_its_light_at_once() -> void:
	var light := (load("res://game/world/light_control.gd") as GDScript).new() as Node2D
	light.set(&"pattern_id", &"Outside Global Light")
	WorldClock.set_time(_day, 18 * 60 + 59)
	add_child_autofree(light)
	var sky := light.get_child(0) as CanvasModulate
	assert_eq(sky.color, Color.WHITE)
	WorldClock.advance_minutes(1)
	await wait_physics_frames(2)
	var night: Color = light.get(&"SKY_NIGHT")
	assert_false(sky.color.is_equal_approx(night), "dusk takes its time")
	await wait_physics_frames(2)
	WorldClock.advance_minutes(MINUTES_PER_DAY)
	assert_true(sky.color.is_equal_approx(night), "a day skipped to 19:00 is night at once")
	WorldClock.set_time(_day, 7 * 60)
	await wait_physics_frames(2)
	WorldClock.advance_minutes(MINUTES_PER_DAY)
	assert_true(sky.color.is_equal_approx(Color.WHITE), "and to 07:00 day at once")

static func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key
