extends GutTest

## Farm1's fish: where, when and in which weather each one bites. How fishing
## works is tested on fixture content with the lifesim module.

var _clock_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()

func after_each() -> void:
	WorldClock.load_save_data(_clock_snapshot)

func test_river_trout_bites_at_riverside_on_spring_days_until_evening() -> void:
	var trout := FishData.find(&"river_trout")
	assert_not_null(trout)
	if trout == null:
		return
	assert_true(trout.is_available(&"riverside_town", 1, 8 * 60, &"clear"))
	assert_false(trout.is_available(&"harbor_town", 1, 8 * 60, &"clear"))
	assert_false(trout.is_available(&"riverside_town", 29, 8 * 60, &"clear"), "no trout in summer")
	assert_false(trout.is_available(&"riverside_town", 1, 21 * 60, &"clear"), "no trout at 21:00")

func test_carp_live_in_the_river_and_sardines_in_the_harbor() -> void:
	WorldClock.set_time(1, 13 * 60)
	var service := FishingService.new()
	add_child_autofree(service)
	var river := service.get_available_fish(&"riverside_town")
	var harbor := service.get_available_fish(&"harbor_town")
	assert_true(river.any(func(f: FishData) -> bool: return f.id == &"river_carp"))
	assert_false(river.any(func(f: FishData) -> bool: return f.id == &"sardine"))
	assert_true(harbor.any(func(f: FishData) -> bool: return f.id == &"sardine"))
	assert_false(harbor.any(func(f: FishData) -> bool: return f.id == &"river_carp"))

func test_storm_eel_bites_only_in_the_harbor_during_storms() -> void:
	var eel := FishData.find(&"storm_eel")
	assert_not_null(eel)
	if eel == null:
		return
	assert_true(eel.is_available(&"harbor_town", 1, 12 * 60, &"storm"))
	assert_false(eel.is_available(&"harbor_town", 1, 12 * 60, &"clear"))
	assert_false(eel.is_available(&"riverside_town", 1, 12 * 60, &"storm"))
