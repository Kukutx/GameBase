extends GutTest

## Staying up too late (`LateNight`, `LifesimSettings`): the minute a wait
## stops at, what the player wakes with, and the settings' problems.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const ENERGY := &"fixture_energy"
const HP := &"fixture_hp"

var _vitals_snapshot: Dictionary

func before_each() -> void:
	_vitals_snapshot = Vitals.to_save_data()
	ContentFixture.use(self, [ContentFixture.vital(ENERGY, 80), ContentFixture.vital(HP)])
	var settings := LifesimSettings.new()
	settings.energy_vital_id = ENERGY
	settings.late_night_minute = 2 * 60
	settings.late_night_energy_percent = 25
	ContentFixture.use_settings(self, [settings])
	Vitals.reset_new_game()

func after_each() -> void:
	ContentRegistry.active = ContentDB
	Vitals.load_save_data(_vitals_snapshot)

func test_a_wait_stops_at_the_late_night_minute_while_a_player_is_up() -> void:
	assert_false(bool(LateNight.call("_is_wait_stop", 1, 2 * 60)), "nobody is up")
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	assert_true(bool(LateNight.call("_is_wait_stop", 1, 2 * 60)))
	assert_false(bool(LateNight.call("_is_wait_stop", 1, 2 * 60 + 1)))
	LifesimSettings.current().late_night_minute = -1
	assert_false(bool(LateNight.call("_is_wait_stop", 1, 2 * 60)), "a game without late nights")

func test_a_player_who_stayed_up_wakes_with_part_of_their_energy() -> void:
	Vitals.set_value(ENERGY, 70)
	Vitals.set_value(HP, 10)
	LateNight.call("_recover")
	assert_eq(Vitals.get_value(ENERGY), 20, "a quarter of 80")
	assert_true(Vitals.is_full(HP), "what sleep refills is full")

func test_the_settings_problems_are_named() -> void:
	var registry := ContentRegistry.active
	var settings := LifesimSettings.new()
	assert_eq(settings.find_problems(registry), PackedStringArray(), "the defaults: no energy, home at 02:00")
	settings.energy_vital_id = &"fixture_mana"
	settings.late_night_minute = GameCalendar.current().wake_minute
	assert_eq(settings.find_problems(registry), PackedStringArray([
		"energy vital 'fixture_mana' is no vital",
		"late night sends the player home at the minute they wake",
	]))
	settings.energy_vital_id = ENERGY
	settings.late_night_minute = 2000
	assert_eq(settings.find_problems(registry), PackedStringArray(["late night minute 2000 is neither -1 nor a minute of the day"]))
